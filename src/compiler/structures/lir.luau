--!strict

local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")

export type Return = {
    kind: "return",
    ty: hir.DeclId<hir.Type>,
}

export type Argument = {
    kind: "argument",
    ty: hir.DeclId<hir.Type>,
    name: string?,
}

export type ConstantValue = 
    | number
    | string
    | boolean

export type Constant<T = ConstantValue> = {
    kind: "constant",
    value: T
}

--- An index into the arguments table
export type ArgumentId = {
    kind: "argument",
    index: number,
}

--- An index into the register table
export type RegisterId = {
    kind: "register",
    index: number,
}

export type Id = 
    | ArgumentId
    | RegisterId
;

--- base(args...)
export type ProjCall = {
    kind: "call",
    base: LValue,
    args: {Value}
}

--- base[field]
export type ProjField = {
    kind: "field",
    base: LValue,
    field: LValue
}

--- base.index
export type ProjIndex = {
    kind: "index",
    base: LValue,
    element: Constant<string>
}

export type Projection =
    | ProjCall
    | ProjField
    | ProjIndex
;

--- left * right
export type BinaryAdd = {
    kind: "add",
    left: LRValue,
    right: LRValue
}

--- left * right
export type BinaryMul = {
    kind: "mul",
    left: LRValue,
    right: LRValue
}
export type BinaryOp =
    | BinaryAdd
    | BinaryMul

--- #%of
export type UnaryLen = {
    kind: "len",
    of: LValue,
}

export type UnaryOp = 
    | UnaryLen
    
--- advance(bytes)
export type CtrlAdvance = {
    kind: "advance",
    bytes: LRValue
}

--- allocate(bytes)
export type CtrlAllocate = {
    kind: "allocate",
    bytes: LRValue
}

export type Control =
    | CtrlAdvance
    | CtrlAllocate

-- Libraries

export type LValue = 
    | Id
    | Projection
    | Constant<string>
;

export type RValue =
    | UnaryOp
    | BinaryOp
    | Constant<number>
    | Constant<boolean>
;

export type LRValue = 
    | LValue
    | RValue
;

export type Condition = {
    kind: "Equals" | "NotEquals" | "LessThan" | "LessThanOr" | "GreaterThan" | "GreaterThanOr",
    left: Value,
    right: Value
}

export type Value = 
    | LValue
    | RValue
    | Control
    | Condition
;

--- call
export type StatCall = {
    kind: "call",
    call: ProjCall
}

--- %into = value
export type StatAssign = {
    kind: "assign",
    into: RegisterId,
    value: Value?,
}

export type Statement = 
    | StatCall
    | StatAssign
;

--- numeric for `%index` = 1, `iterations` do
export type LoopNumeric = {
    kind: "numeric",
    index: RegisterId,
    iterations: LRValue,
}

--- generic for `%index`, `%value% in `target` do
export type LoopGeneric = {
    kind: "generic",
    index: RegisterId?,
    value: RegisterId,
    target: LValue
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
    falsey: BasicBlock
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
    args: {Value},
    destination: BasicBlock,
}

export type TermReturn = {
    kind: "return",
    values: { Value }
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
    decl: hir.DeclId<hir.Type>,

    read: FnId,
    write: FnId,
    exported: boolean,
}

export type Event = {
    kind: "event",
    decl: hir.DeclId<hir.Event>,

    read: FnId,
    write: FnId,
}

export type Function = {
    kind: "function",
    decl: hir.DeclId<hir.Function>,
    
    read: FnId,
    write: FnId,
}

export type Lir = {
    fns: {Fn},
    types: {Type},
    events: {Event},
    functions: {Function}
}

return nil