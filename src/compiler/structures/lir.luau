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
    __phantom_type: T,

    type: "constant",
    value: T
}

--- An index into the arguments table
export type ArgumentId<T> = {
    __phantom_type: T,

    type: "id",
    kind: "argument",
    index: number
}

--- An index into the register table
export type RegisterId<T> = {
    __phantom_type: T,

    type: "id",
    kind: "register",
    index: number
}

export type Id<T> = 
    | ArgumentId<T>
    | RegisterId<T>
;

--- base(args...)
export type ProjCall<T> = {
    __phantom_type: T,

    type: "projection",
    kind: "call",
    base: LValue<any> | Constant<string>,
    args: {RValue<any>}
}

--- base[field]
export type ProjField<T> = {
    __phantom_type: T,

    type: "projection",
    kind: "field",
    base: LValue<any> | Constant<string>,
    field: RValue<any>
}

--- base.index
export type ProjIndex<T> = {
    __phantom_type: T,

    type: "projection",
    kind: "index",
    base: LValue<any> | Constant<string>,
    element: Constant<string>
}

--- base:method(args...)
export type ProjNamecall<T> = {
    __phantom_type: T,

    type: "projection",
    kind: "namecall",
    base: LValue<any> | Constant<string>,
    method: Constant<string>,
    args: {RValue<any>}
}

export type Projection<T> =
    | ProjCall<T>
    | ProjField<T>
    | ProjIndex<T>
    | ProjNamecall<T>
;

--- left + right
export type BinaryAdd<T> = {
    __phantom_type: T,

    type: "binary",
    kind: "add",
    left: RValue<T>,
    right: RValue<T>
}

--- left - right
export type BinarySub<T> = {
    __phantom_type: T,

    type: "binary",
    kind: "sub",
    left: RValue<T>,
    right: RValue<T>
}

--- left * right
export type BinaryMul<T> = {
    __phantom_type: T,

    type: "binary",
    kind: "mul",
    left: RValue<T>,
    right: RValue<T>
}

--- left / right
export type BinaryDiv<T> = {
    __phantom_type: T,

    type: "binary",
    kind: "div",
    left: RValue<T>,
    right: RValue<T>
}

--- left % right
export type BinaryMod<T> = {
    __phantom_type: T,

    type: "binary",
    kind: "mod",
    left: RValue<T>,
    right: RValue<T>
}

export type BinaryOp<T> =
    | BinaryAdd<T>
    | BinarySub<T>
    | BinaryMul<T>
    | BinaryDiv<T>
    | BinaryMod<T>

--- #%of
export type UnaryLen<T> = {
    __phantom_type: T,

    type: "unary",
    kind: "len",
    of: RValue<T>,
}

export type UnaryOp<T> = 
    | UnaryLen<T>
    
--- advance(bytes)
export type CtrlAdvance<T> = {
    __phantom_type: T,

    type: "control",
    kind: "advance",
    bytes: RValue<T>
}

--- allocate(bytes)
export type CtrlAllocate<T> = {
    __phantom_type: T,

    type: "control",
    kind: "allocate",
    bytes: RValue<T>
}

export type Control<T> =
    | CtrlAdvance<T>
    | CtrlAllocate<T>
;

export type Global<T> = {
    __phantom_type: T,

    type: "global",
    identifier: string
}

--- left == / ~=/ >= / > / < / <= right
export type Condition<T> = {
    __phantom_type: T,

    type: "condition",
    kind: "equals" | "not_equals" | "less_than" | "less_than_or" | "greater_than" | "greater_than_or",
    left: RValue<T>,
    right: RValue<T>
}

--- if cond then left else right
export type Ternary<T> = {
    __phantom_type: T,

    type: "ternary",
    cond: Condition<T>,
    left: RValue<T>,
    right: RValue<T>
}

-- { values }
export type Map<T> = {
    __phantom_type: {T},

    type: "structure",
    kind: "map",
    values: {[RValue<any>]: RValue<any>}
}

-- { values }
export type Array<T> = {
    __phantom_type: {T},

    type: "structure",
    kind: "array",
    values: {RValue<T>}
}

-- { values }
export type Struct<T> = {
    __phantom_type: {T},

    type: "structure",
    kind: "struct",
    values: {[Constant<string>]: RValue<T>}
}

export type Structure<T> = 
    | Map<T>
    | Array<T>
    | Struct<T>
;

--- left side of an assign statement
export type LValue<T> = 
    | ProjField<T>
    | ProjIndex<T>
    | RegisterId<T>
    | ArgumentId<T>
;

--- right side of an assign statement
export type RValue<T> =
    | Id<T>
    | Structure<T>
    | Global<T>
    | Control<T>
    | Ternary<T>
    | UnaryOp<T>
    | BinaryOp<T>
    | Condition<T>
    | Constant<T>
    | Projection<T>
;

--- call
export type StatCall = {
    type: "statement",
    kind: "call",
    call: ProjCall<any>
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
    into: LValue<any>,
    value: RValue<any>?,
}

--- %a, %b, %c = value
export type StatMultiAssign = {
    type: "statement",
    kind: "multi_assign",
    into: {LValue<any>},
    value: RValue<any>,
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
    index: RegisterId<number>,
    iterations: RValue<number>,
}

--- generic for `%index`, `%value` in `%target` do
export type LoopGeneric = {
    type: "loop",
    kind: "generic",
    index: RegisterId<any>,
    value: RegisterId<any>,
    target: RValue<{[any]: any}>
}

export type Loop = 
    | LoopNumeric
    | LoopGeneric
;

--- jump to `truthy` if `cond` evaluates to `true`
export type TermIf = {
    type: "terminator",
    kind: "if",
    cond: Condition<any>,
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
    args: { RValue<any> },
    destination: BasicBlock,
}

export type TermReturn = {
    type: "terminator",
    kind: "return",
    values: { RValue<any> }
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

export type FnId = any & { __fn: true }

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