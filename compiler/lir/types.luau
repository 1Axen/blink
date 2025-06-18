--!strict

local hir = require("@hir/types")
local ty = require("@ty/types")

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

--stylua: ignore
export type Id<T> = 
    | ArgumentId<T>
    | RegisterId<T>

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

--- right side of an assign statement
--stylua: ignore
export type RValue<T> =
	| RegisterId<T>
	| ArgumentId<T>
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
	fn: SetId,
	args: { RValue<any> },
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
	index: number,
	scope: number,
	statements: { Statement },
	terminator: Terminator,
}

export type Fn = {
	type: "fn",
	name: string,

	rets: { Return },
	args: { Argument },
	blocks: { BasicBlock },
}

export type SetId = any & { __fn_set: true }

export type Type = {
	type: "type",
	decl: hir.Type,
	set: SetId,
}

export type Event = {
	type: "event",
	decl: hir.Event,
	set: SetId,
}

export type Function = {
	type: "function",
	decl: hir.Function,
	set: SetId,
}

export type Set = {
	read: Fn,
	write: Fn,
}

export type Lir = {
	sets: { [SetId]: Set },
	types: { [hir.DeclId]: Type },
	events: { [hir.DeclId]: Event },
	functions: { [hir.DeclId]: Function },
}

local function set_from_id(lir: Lir, set_id: SetId): Set
	local set = lir.sets[set_id]
	if set == nil then
		return panic("Expected set_id to point to a set")
	end

	return set
end

return table.freeze({
	set_from_id = set_from_id,
})
