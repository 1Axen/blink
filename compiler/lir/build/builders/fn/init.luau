local control = require("@builders/control")
local globals = require("@builders/globals")
local lir = require("@lir/types")
local ty = require("@ty/types")

local panic = require("@util/panic")

local basic_block = require("@self/basic_block")
local statement = require("@self/statement")
local terminator = require("@self/terminator")

local context = require("@lir/build/context")

local loop = require("@builders/loop")

type Ty = ty.Ty

type Fn = lir.Fn
type FnId = lir.FnId

type Return = lir.Return
type Argument = lir.Argument

type BasicBlock = lir.BasicBlock

type Loop = lir.Loop
type Condition = lir.Condition<boolean>

type LValue<T = any> = lir.LValue<T>
type RValue<T = any> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Context = context.Context

type Body = (block: Builder) -> ()
type NumericLoopBody = (block: Builder, index: Register<number>) -> ()
type GenericLoopBody = (block: Builder, index: Register<any>, value: Register<any>) -> ()

local MAX_REGISTERS = 200
local REGISTERS_TEMPLATE = table.create(MAX_REGISTERS, 0)

for index = 1, MAX_REGISTERS do
	REGISTERS_TEMPLATE[index] = (index - 1)
end

local function rreturn(ty: Ty): lir.Return
	return {
		type = "return",
		ty = ty,
	}
end

local function argument(ty: Ty, name: string?): lir.Argument
	return {
		type = "argument",
		ty = ty,
		name = name,
	}
end

local function register<T>(builder: Builder): Register<T>
	local index = table.remove(builder.registers, 1)
	if index == nil then
		return panic(`Function exceeded {MAX_REGISTERS} registers`)
	end

	return {
		__phantom_type = nil :: any,

		type = "id",
		kind = "register",
		index = index,
	}
end

local function store<T, R>(self: Builder, value: RValue<T>, into: LValue<R>?): Register<T>
	local register = (into or register(self))
	local assign = statement.assign(register, value)
	table.insert(self.block.statements, assign)
	return register :: Register<T>
end

local function reserve(self: Builder): Register<any>
	local register = register(self)
	local assign = statement.assign(register)
	table.insert(self.block.statements, assign)
	return register
end

--- Store the result of `value` into `count` registers
local function store_mult(self: Builder, value: RValue, count: number): { LValue }
	local registers: { LValue } = {}
	for index = 1, count do
		registers[index] = register(self)
	end

	local stat = statement.multi_assign(registers, value)
	table.insert(self.block.statements, stat)

	return registers
end

local function allocate(self: Builder, bytes: lir.RValue<number>): Register<number>
	local cursor = self:store(globals.incoming.cursor)
	self:call(control.allocate(bytes))
	return cursor
end

local function call<T>(self: Builder, call: lir.ProjCall<T> | lir.ProjNamecall<T> | lir.CtrlAllocate<T>)
	local stat = statement.call(call)
	table.insert(self.block.statements, stat)
end

local function remark(self: Builder, text: string)
	table.insert(self.block.statements, statement.remark(text))
end

local function branch(self: Builder, cond: Condition, body: Body, chained: boolean)
	local current = self.block
	local truthy_block = basic_block.create(current.scope + 1)
	local falsey_block = basic_block.create(current.scope, current.terminator)

	current.terminator = terminator.ifbr(cond, truthy_block, falsey_block, chained)
	truthy_block.terminator = terminator.goto(falsey_block)

	--> set block to loop
	self.block = truthy_block
	table.insert(self.blocks, truthy_block)

	--> populate the loop
	body(self)

	--> set block to after loop
	self.block = falsey_block
	table.insert(self.blocks, falsey_block)
end

local function rtrn(self: Builder, values: { RValue })
	local current = self.block
	if current.terminator.kind ~= "none" then
		panic("Early return")
	end

	current.terminator = terminator.rtrn(values)
end

local function if_branch(self: Builder, cond: Condition, body: Body)
	branch(self, cond, body, false)
end

local function elseif_branch(self: Builder, cond: Condition, body: Body)
	--branch(self, cond, body, true)
end

local function else_branch(self: Builder, body: Body)
	--branch(self, condition.always(), body, true)
end

local function for_numeric(self: Builder, iterations: RValue<number>, body: NumericLoopBody)
	local prev_block = self.block
	local loop_block = basic_block.create(prev_block.scope + 1)
	local after_block = basic_block.create(prev_block.scope, prev_block.terminator)

	loop_block.terminator = terminator.goto(after_block)

	self.block = loop_block
	table.insert(self.blocks, loop_block)

	local index_register = register(self) :: Register<number>
	local numeric_loop = loop.numeric(index_register, iterations)
	prev_block.terminator = terminator.loop(numeric_loop, loop_block)

	body(self, index_register)

	self.block = after_block
	table.insert(self.blocks, after_block)
end

local function for_generic(self: Builder, target: index<lir.LoopGeneric, "target">, body: GenericLoopBody)
	local prev_block = self.block
	local loop_block = basic_block.create(prev_block.scope + 1)
	local after_block = basic_block.create(prev_block.scope, prev_block.terminator)

	loop_block.terminator = terminator.goto(after_block)

	self.block = loop_block
	table.insert(self.blocks, loop_block)

	local index_register = register(self)
	local value_register = register(self)
	local numeric_loop = loop.generic(index_register, value_register, target)
	prev_block.terminator = terminator.loop(numeric_loop, loop_block)

	body(self, index_register, value_register)

	self.block = after_block
	table.insert(self.blocks, after_block)
end

local function while_loop(self: Builder, condition: Condition, body: Body)
	local current = self.block
	local truthy_block = basic_block.create(current.scope + 1)
	local falsey_block = basic_block.create(current.scope, current.terminator)

	current.terminator = terminator.while_loop(condition, truthy_block, falsey_block)
	truthy_block.terminator = terminator.goto(falsey_block)

	--> set block to loop
	self.block = truthy_block
	table.insert(self.blocks, truthy_block)

	--> populate the loop
	body(self)

	--> set block to after loop
	self.block = falsey_block
	table.insert(self.blocks, falsey_block)
end

local function call_fn(self: Builder, fn_id: FnId, args: { RValue }, rets: { LValue })
	local prev_block = self.block
	local next_block = basic_block.create(prev_block.scope, prev_block.terminator)

	prev_block.terminator = terminator.call(fn_id, args, rets, next_block)

	self.block = next_block
	table.insert(self.blocks, next_block)
end

export type Builder = {
	ctx: Context,
	block: BasicBlock,
	blocks: { BasicBlock },
	registers: { number },

	store: typeof(store),
	reserve: typeof(reserve),
	store_mult: typeof(store_mult),

	allocate: typeof(allocate),

	call: typeof(call),
	call_fn: typeof(call_fn),

	remark: typeof(remark),

	rtrn: typeof(rtrn),

	if_branch: typeof(if_branch),
	elseif_branch: typeof(elseif_branch),
	else_branch: typeof(else_branch),

	for_numeric: typeof(for_numeric),
	for_generic: typeof(for_generic),

	while_loop: typeof(while_loop),

	argument: (self: Builder, index: number) -> lir.ArgumentId<any>,
}

local function create(ctx: Context, name: index<Fn, "name">, args: { Argument }, rets: { Return }, body: Body): Fn
	local function argument_id(self: Builder, index: number): lir.ArgumentId<any>
		if index > #args then
			return panic(`tried using argument #{index}, but fn only has {#args} argument(s)`)
		elseif index < 0 then
			return panic(`negative argument id #{index}`)
		end

		return {
			__phantom_type = nil :: any,

			type = "id",
			kind = "argument",
			index = index,
		}
	end

	local entry = basic_block.create()
	local builder: Builder = {
		ctx = ctx,
		block = entry,
		blocks = { entry },
		registers = table.clone(REGISTERS_TEMPLATE),

		store = store,
		reserve = reserve,
		store_mult = store_mult,

		allocate = allocate,

		call = call,
		call_fn = call_fn,

		remark = remark,

		loop = loop,
		rtrn = rtrn,

		if_branch = if_branch,
		elseif_branch = elseif_branch,
		else_branch = else_branch,

		for_numeric = for_numeric,
		for_generic = for_generic,

		while_loop = while_loop,

		argument = argument_id,
	}

	--> run the body
	body(builder)

	--> return fn
	return {
		type = "fn",
		id = 0,
		name = name,
		rets = rets,
		args = args,
		blocks = builder.blocks,
	}
end

return table.freeze({
	create = create,
	rreturn = rreturn,
	argument = argument,
})
