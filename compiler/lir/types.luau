--!strict

local hir = require("@hir/types")
local panic = require("@util/panic")
local ty = require("@ty/types")

type Ty = ty.Ty
type TyId = ty.TyId

export type Return = {
	kind: "return",
	ty: Ty,
}

export type Argument = {
	kind: "argument",
	ty: Ty,
	name: string?,
}

--stylua: ignore
export type ConstantValue = 
    | number
    | string
    | boolean
    | nil

export type Constant<T = ConstantValue> = {
	write __phantom_type: T,

	type: "constant",
	value: T,
}

--- An index into the arguments table
export type ArgumentId<T> = {
	write __phantom_type: T,

	type: "id",
	kind: "argument",
	index: number,
}

--- An index into the register table
export type RegisterId<T> = {
	write __phantom_type: T,

	type: "id",
	kind: "register",
	index: number,
}

--- Index into the upvalue table
export type UpvalueId<T> = {
	write __phantom_type: T,

	type: "id",
	kind: "upvalue",
	index: string,
}

--stylua: ignore
export type Id<T> =
    | ArgumentId<T>
    | RegisterId<T>
    | UpvalueId<T>

--- base(args...)
export type ProjCall<T> = {
	write __phantom_type: T,

	type: "projection",
	kind: "call",
	base: LValue<T> | Constant<T>,
	args: { RValue<T> },
}

--- base[field]
export type ProjField<T> = {
	write __phantom_type: T,

	type: "projection",
	kind: "field",
	base: LValue<T> | Constant<T>,
	field: RValue<T>,
}

--- base.index
export type ProjIndex<T> = {
	write __phantom_type: T,

	type: "projection",
	kind: "index",
	base: LValue<T> | Constant<T>,
	element: Constant<T>,
}

--- base:method(args...)
export type ProjNamecall<T> = {
	write __phantom_type: T,

	type: "projection",
	kind: "namecall",
	base: LValue<T> | Constant<T>,
	method: Constant<T>,
	args: { RValue<T> },
}

export type ProjShapedTable<T> = {
	write __phantom_type: T,

	type: "projection",
	kind: "shaped_table",
	base: LValue<T>,
	shape: { string },
}

--stylua: ignore
export type Projection<T> =
    | ProjCall<T>
    | ProjField<T>
    | ProjIndex<T>
    | ProjNamecall<T>

--- left + right
export type BinaryAdd<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "add",
	left: RValue<T>,
	right: RValue<T>,
}

--- left - right
export type BinarySub<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "sub",
	left: RValue<T>,
	right: RValue<T>,
}

--- left * right
export type BinaryMul<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "mul",
	left: RValue<T>,
	right: RValue<T>,
}

--- left / right
export type BinaryDiv<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "div",
	left: RValue<T>,
	right: RValue<T>,
}

--- left % right
export type BinaryMod<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "mod",
	left: RValue<T>,
	right: RValue<T>,
}

--- left // right
export type BinaryIDiv<T> = {
	write __phantom_type: T,

	type: "binary",
	kind: "idiv",
	left: RValue<T>,
	right: RValue<T>,
}

--stylua: ignore
export type BinaryOp<T> =
    | BinaryAdd<T>
    | BinarySub<T>
    | BinaryMul<T>
    | BinaryDiv<T>
    | BinaryMod<T>
    | BinaryIDiv<T>

--- #%of
export type UnaryLen<T> = {
	write __phantom_type: T,

	type: "unary",
	kind: "len",
	of: RValue<T>,
}

--stylua: ignore
export type UnaryOp<T> = 
    | UnaryLen<T>

--- advance(bytes)
export type CtrlAdvance<T> = {
	write __phantom_type: T,

	type: "control",
	kind: "advance",
	bytes: RValue<T>,
}

--- allocate(bytes)
export type CtrlAllocate<T> = {
	write __phantom_type: T,

	type: "control",
	kind: "allocate",
	bytes: RValue<T>,
}

--stylua: ignore
export type Control<T> = 
	| CtrlAdvance<T> 
	| CtrlAllocate<T>

export type Global<T> = {
	write __phantom_type: T,

	type: "global",
	identifier: string,
}

--- left == / ~=/ >= / > / < / <= right
export type Condition<T> = {
	write __phantom_type: T,

	type: "condition",
	kind: "equals" | "not_equals" | "less_than" | "less_than_or" | "greater_than" | "greater_than_or",
	left: RValue<T>,
	right: RValue<T>,
}

--- if cond then left else right
export type Ternary<T> = {
	write __phantom_type: T,

	type: "ternary",
	cond: Condition<T>,
	left: RValue<T>,
	right: RValue<T>,
}

-- { values }
export type Map<T> = {
	write __phantom_type: { T },

	type: "structure",
	kind: "map",
	values: { [RValue<T>]: RValue<T> },
}

-- { values }
export type Array<T> = {
	write __phantom_type: { T },

	type: "structure",
	kind: "array",
	values: { RValue<T> },
}

-- { values }
export type Struct<T> = {
	write __phantom_type: { T },

	type: "structure",
	kind: "struct",
	values: { [Constant<T>]: RValue<T> },
}

--stylua: ignore
export type Structure<T> = 
    | Map<T>
    | Array<T>
    | Struct<T>

--- left side of an assign statement
--stylua: ignore
export type LValue<T> =
    | Global<T>
    | ProjField<T>
    | ProjIndex<T>
    | RegisterId<T>
    | ArgumentId<T>
    | UpvalueId<T>

--- right side of an assign statement
--stylua: ignore
export type RValue<T> =
	| RegisterId<T>
	| ArgumentId<T>
	| UpvalueId<T>
	| Structure<T>
	| Global<T>
	| Control<T>
	| Ternary<T>
	| UnaryOp<T>
	| BinaryOp<T>
	| Condition<T>
	| Constant<T>
	| Projection<T>

--- call
export type StatCall = {
	type: "statement",
	kind: "call",
	call: ProjCall<any>,
}

--- -- REMARK text
export type StatRemark = {
	type: "statement",
	kind: "remark",
	text: string,
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
	into: { LValue<any> },
	value: RValue<any>,
}

--stylua: ignore
export type Statement = 
    | StatCall
    | StatAssign
    | StatRemark
    | StatMultiAssign

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
	target: RValue<{ [any]: any }>,
}

--stylua: ignore
export type Loop = 
    | LoopNumeric
    | LoopGeneric

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
	destination: BasicBlock,
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
	rets: { LValue<any> },
	destination: BasicBlock,
}

export type TermReturn = {
	type: "terminator",
	kind: "return",
	values: { RValue<any> },
}

--stylua: ignore
export type Terminator = 
    | TermIf
    | TermLoop
    | TermCall
    | TermGoto
    | TermNone
    | TermReturn

export type BasicBlock = {
	type: "block",
	scope: number,
	statements: { Statement },
	terminator: Terminator,
}

export type Fn = {
	type: "fn",
	id: FnId,
	name: string,

	rets: { Return },
	args: { Argument },
	blocks: { BasicBlock },
}

export type FnId = number | { __fn: true }

export type FnSet = {
	read: FnId,
	write: FnId,
}

export type Type = {
	type: "type",
	decl: hir.Type,
	set: FnSet,
}

export type Event = {
	type: "event",
	decl: hir.Event,
	set: FnSet,
}

export type Function = {
	type: "function",
	decl: hir.Function,
	set: FnSet,
}

export type Lir = {
	fns: { [FnId]: Fn },
	tys: { [TyId]: FnSet },
	types: { [hir.DeclId]: Type },
	events: { [hir.DeclId]: Event },
	functions: { [hir.DeclId]: Function },

	-- mutable upvalues
	upvalues: { [UpvalueId<any>]: RValue<any> },
}

local function fn_from_id(lir: Lir, fn_id: FnId): Fn
	local fn = lir.fns[fn_id]
	if fn == nil then
		return panic("Expected fn id to point to a fn")
	end

	return fn
end

return table.freeze({
	fn_from_id = fn_from_id,
})
