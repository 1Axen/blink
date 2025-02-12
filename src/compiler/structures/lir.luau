--!strict

local ty = require("@structures/ty")
local hir = require("@structures/hir")

local panic = require("@util/panic")

export type Return = {
    kind: "return",
    ty: ty.Ty,
}

export type Argument = {
    kind: "argument",
    ty: ty.Ty,
    name: string?,
}

export type ConstantValue = 
    | number
    | string
    | boolean
    | nil

export type Constant<T = ConstantValue> = {
    kind: "constant",
    value: T
}

--- An index into the arguments table
export type ArgumentId = {
    kind: "argument",
    index: number
}

--- An index into the register table
export type RegisterId = {
    kind: "register",
    index: number
}

export type Id = 
    | ArgumentId
    | RegisterId
;

--- base(args...)
export type ProjCall = {
    kind: "call",
    base: LValue | Constant<string>,
    args: {RValue}
}

--- base[field]
export type ProjField = {
    kind: "field",
    base: LValue | Constant<string>,
    field: RValue
}

--- base.index
export type ProjIndex = {
    kind: "index",
    base: LValue | Constant<string>,
    element: Constant<string>
}

--- base:method(args...)
export type ProjNamecall = {
    kind: "namecall",
    base: LValue | Constant<string>,
    method: Constant<string>,
    args: {RValue}
}

export type Projection =
    | ProjCall
    | ProjField
    | ProjIndex
    | ProjNamecall
;

--- left + right
export type BinaryAdd = {
    kind: "add",
    left: RValue,
    right: RValue
}

--- left - right
export type BinarySub = {
    kind: "sub",
    left: RValue,
    right: RValue
}

--- left * right
export type BinaryMul = {
    kind: "mul",
    left: RValue,
    right: RValue
}

--- left / right
export type BinaryDiv = {
    kind: "div",
    left: RValue,
    right: RValue
}

--- left % right
export type BinaryMod = {
    kind: "mod",
    left: RValue,
    right: RValue
}

export type BinaryOp =
    | BinaryAdd
    | BinarySub
    | BinaryMul
    | BinaryDiv
    | BinaryMod

--- #%of
export type UnaryLen = {
    kind: "len",
    of: RValue,
}

export type UnaryOp = 
    | UnaryLen
    
--- advance(bytes)
export type CtrlAdvance = {
    kind: "advance",
    bytes: RValue
}

--- allocate(bytes)
export type CtrlAllocate = {
    kind: "allocate",
    bytes: RValue
}

export type Control =
    | CtrlAdvance
    | CtrlAllocate
;

--- left == / ~=/ >= / > / < / <= right
export type Condition = {
    kind: "equals" | "not_equals" | "less_than" | "less_than_or" | "greater_than" | "greater_than_or",
    left: RValue,
    right: RValue
} | {
    kind: "always",
    left: nil,
    right: nil
}

--- if cond then left else right
export type Ternary = {
    kind: "ternary",
    cond: Condition,
    left: RValue,
    right: RValue
}

-- { values }
export type WrapTable = {
    kind: "table",
    values: {RValue}
}

-- (value)
export type WrapSingle = {
    kind: "single",
    value: RValue
}

export type Wrapper = 
    | WrapTable
    | WrapSingle
;

--- left side of an assign statement
export type LValue = 
    | ProjField
    | ProjIndex
    | RegisterId
    | ArgumentId
;

--- right side of an assign statement
export type RValue =
    | Id
    | Wrapper
    | Control
    | Ternary
    | UnaryOp
    | BinaryOp
    | Condition
    | Constant<nil>
    | Constant<string>
    | Constant<number>
    | Constant<boolean>
    | Projection
;

--- call
export type StatCall = {
    kind: "call",
    call: ProjCall
}

--- %into = value
export type StatAssign = {
    kind: "assign",
    into: LValue,
    value: RValue?,
}

--- %a, %b, %c = value
export type StatMultiAssign = {
    kind: "multi_assign",
    into: {LValue},
    value: RValue,
}

export type Statement = 
    | StatCall
    | StatAssign
    | StatMultiAssign
;

--- numeric for `%index` = 1, `%iterations` do
export type LoopNumeric = {
    kind: "numeric",
    index: RegisterId,
    iterations: RegisterId,
}

--- generic for `%index`, `%value` in `%target` do
export type LoopGeneric = {
    kind: "generic",
    index: RegisterId?,
    value: RegisterId,
    target: Id | ProjField | ProjIndex
}

export type Loop = 
    | LoopNumeric
    | LoopGeneric
;

--- jump to `truthy` if `cond` evaluates to `true`
export type TermIf = {
    kind: "if",
    cond: Condition,
    truthy: BasicBlock,
    falsey: BasicBlock,

    -- elseif
    chained: boolean?,
}

--- placeholder
export type TermNone = {
    kind: "none",
}

export type TermGoto = {
    kind: "goto",
    destination: BasicBlock
}

export type TermLoop = {
    kind: "loop",
    loop: Loop,
    destination: BasicBlock,
}

export type TermCall = {
    kind: "call",
    fn: FnId,
    args: { RValue },
    destination: BasicBlock,
}

export type TermReturn = {
    kind: "return",
    values: { RValue }
}

export type Terminator = 
    | TermIf
    | TermLoop
    | TermCall
    | TermGoto
    | TermNone
    | TermReturn

export type BasicBlock = {
    kind: "block",
    index: number,
    scope: number,
    statements: {Statement},
    terminator: Terminator
}

export type Fn = {
    kind: "fn",
    name: string,

    rets: {Return},
    args: {Argument},
    blocks: {BasicBlock},
}

export type FnId = number & { __fn: true }

export type Type = {
    kind: "type",
    decl: hir.Type,
    read: FnId,
    write: FnId,
}

export type Event = {
    kind: "event",
    decl: hir.Event,
    read: FnId,
    write: FnId,
}

export type Function = {
    kind: "function",
    decl: hir.Function,
    read: FnId,
    write: FnId,
}

export type Lir = {
    fns: {[FnId]: Fn},
    types: {[hir.DeclId]: Type},
    events: {[hir.DeclId]: Event},
    functions: {[hir.DeclId]: Function}
}

local function fn_from_id(lir: Lir, fn_id: FnId): Fn
    local fn = lir.fns[fn_id]
    if fn == nil then
        return panic("Expected fn_id to point to a fn")
    end

    return fn
end

return table.freeze({
    fn_from_id = fn_from_id,
})