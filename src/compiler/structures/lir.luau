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
    type: "constant",
    value: T
}

--- An index into the arguments table
export type ArgumentId = {
    type: "id",
    kind: "argument",
    index: number
}

--- An index into the register table
export type RegisterId = {
    type: "id",
    kind: "register",
    index: number
}

export type Id = 
    | ArgumentId
    | RegisterId
;

--- base(args...)
export type ProjCall = {
    type: "projection",
    kind: "call",
    base: LValue | Constant<string>,
    args: {RValue}
}

--- base[field]
export type ProjField = {
    type: "projection",
    kind: "field",
    base: LValue | Constant<string>,
    field: RValue
}

--- base.index
export type ProjIndex = {
    type: "projection",
    kind: "index",
    base: LValue | Constant<string>,
    element: Constant<string>
}

--- base:method(args...)
export type ProjNamecall = {
    type: "projection",
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
    type: "binary",
    kind: "add",
    left: RValue,
    right: RValue
}

--- left - right
export type BinarySub = {
    type: "binary",
    kind: "sub",
    left: RValue,
    right: RValue
}

--- left * right
export type BinaryMul = {
    type: "binary",
    kind: "mul",
    left: RValue,
    right: RValue
}

--- left / right
export type BinaryDiv = {
    type: "binary",
    kind: "div",
    left: RValue,
    right: RValue
}

--- left % right
export type BinaryMod = {
    type: "binary",
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
    type: "unary",
    kind: "len",
    of: RValue,
}

export type UnaryOp = 
    | UnaryLen
    
--- advance(bytes)
export type CtrlAdvance = {
    type: "control",
    kind: "advance",
    bytes: RValue
}

--- allocate(bytes)
export type CtrlAllocate = {
    type: "control",
    kind: "allocate",
    bytes: RValue
}

export type Control =
    | CtrlAdvance
    | CtrlAllocate
;

export type Global = {
    type: "global",
    identifier: string
}

--- left == / ~=/ >= / > / < / <= right
export type Condition = {
    type: "condition",
    kind: "equals" | "not_equals" | "less_than" | "less_than_or" | "greater_than" | "greater_than_or",
    left: RValue,
    right: RValue
}

--- if cond then left else right
export type Ternary = {
    type: "ternary",
    cond: Condition,
    left: RValue,
    right: RValue
}

-- { values }
export type WrapTable = {
    type: "wrapper",
    kind: "table",
    values: {RValue}
}

-- (value)
export type WrapSingle = {
    type: "wrapper",
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
    | Global
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
    type: "statement",
    kind: "call",
    call: ProjCall
}

--- -- REMARK text
export type StatRemark = {
    type: "statement",
    kind: "remark",
    text: string
}

--- %into = value
export type StatAssign = {
    type: "statement",
    kind: "assign",
    into: LValue,
    value: RValue?,
}

--- %a, %b, %c = value
export type StatMultiAssign = {
    type: "statement",
    kind: "multi_assign",
    into: {LValue},
    value: RValue,
}

export type Statement = 
    | StatCall
    | StatAssign
    | StatRemark
    | StatMultiAssign
;

--- numeric for `%index` = 1, `%iterations` do
export type LoopNumeric = {
    type: "loop",
    kind: "numeric",
    index: RegisterId,
    iterations: RValue,
}

--- generic for `%index`, `%value` in `%target` do
export type LoopGeneric = {
    type: "loop",
    kind: "generic",
    index: RegisterId,
    value: RegisterId,
    target: Id | ProjField | ProjIndex
}

export type Loop = 
    | LoopNumeric
    | LoopGeneric
;

--- jump to `truthy` if `cond` evaluates to `true`
export type TermIf = {
    type: "terminator",
    kind: "if",
    cond: Condition,
    truthy: BasicBlock,
    falsey: BasicBlock,

    -- elseif
    chained: boolean?,
}

--- placeholder
export type TermNone = {
    type: "terminator",
    kind: "none",
}

export type TermGoto = {
    type: "terminator",
    kind: "goto",
    destination: BasicBlock
}

export type TermLoop = {
    type: "terminator",
    kind: "loop",
    loop: Loop,
    destination: BasicBlock,
}

export type TermCall = {
    type: "terminator",
    kind: "call",
    fn: FnId,
    args: { RValue },
    destination: BasicBlock,
}

export type TermReturn = {
    type: "terminator",
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
    type: "block",
    index: number,
    scope: number,
    statements: {Statement},
    terminator: Terminator
}

export type Fn = {
    type: "fn",
    name: string,

    rets: {Return},
    args: {Argument},
    blocks: {BasicBlock},
}

export type FnId = number & { __fn: true }

export type Type = {
    type: "type",
    decl: hir.Type,
    read: FnId,
    write: FnId,
}

export type Event = {
    type: "event",
    decl: hir.Event,
    read: FnId,
    write: FnId,
}

export type Function = {
    type: "function",
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