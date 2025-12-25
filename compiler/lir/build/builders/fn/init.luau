local control = require("@builders/control")
local globals = require("@builders/globals")
local ty = require("@ty")
local types = require("@lir/types")

local panic = require("@util/panic")

local statement = require("@self/statement")
local terminator = require("@self/terminator")

local context = require("@lir/build/context")

local loop = require("@builders/loop")

type Ty = ty.Ty

type Fn = types.Fn
type FnId = types.FnId

type Return = types.Return
type Parameter = types.Parameter

type Terminator = types.Terminator
type BasicBlock = types.BasicBlock

type Loop = types.Loop
type Condition = types.Condition<boolean>

type LValue<T = any> = types.LValue<T>
type RValue<T = any> = types.RValue<T>
type Register<T> = types.RegisterId<T>

type Context = context.Context

type Constructor = (block: Builder) -> ()
type IfChainConstructor = (index: number) -> (Condition, Constructor)
type NumericLoopConstructor = (block: Builder, index: Register<number>) -> ()
type GenericLoopConstructor = (block: Builder, index: Register<any>, value: Register<any>) -> ()

local MAX_REGISTERS = 200

local function fn_return(ty: Ty): types.Return
	return {
		type = "return",
		ty = ty,
	}
end

local function parameter(ty: Ty, name: string?): types.Parameter
	return {
		type = "parameter",
		ty = ty,
		name = name,
	}
end

export type Builder = {
	read store: <T, R>(Builder, value: RValue<T>, into: LValue<R>?) -> Register<T>,
	read capture: (Builder, upvalues: { Register<any> }) -> (),
	read reserve: (Builder) -> Register<any>,
	read parameter: (self: Builder, index: number) -> types.ParameterId<any>,
	read store_mult: (Builder, value: RValue, count: number) -> { LValue },

	read allocate: (Builder, bytes: types.RValue<number>) -> Register<number>,

	read call: <T>(Builder, call: types.ProjCall<T> | types.ProjNamecall<T> | types.CtrlAllocate<T>) -> (),
	read call_fn: (Builder, fn_id: FnId, args: { RValue }, rets: { LValue }) -> (),

	read remark: (Builder, text: string) -> (),

	read rreturn: (Builder, values: { RValue }) -> (),
	read if_chain: (Builder, length: number, constructor: IfChainConstructor) -> (),
	read if_single: (Builder, cond: Condition, body: Constructor) -> (),
	read for_numeric: (Builder, iterations: RValue<number>, body: NumericLoopConstructor) -> (),
	read for_generic: (Builder, target: index<types.LoopGeneric, "target">, body: GenericLoopConstructor) -> (),
	read while_loop: (Builder, condition: Condition, body: Constructor) -> (),
}

local function construct_fn(n_params: number, constructor: Constructor): { BasicBlock }
	local function next_block(scope: number?, term: Terminator?): BasicBlock
		return {
			type = "block",
			scope = scope or 0,
			index = 0,
			statements = {},
			terminator = term or terminator.none() :: Terminator,
		}
	end

	local block = next_block()
	local blocks: { BasicBlock } = { block }
	local register_top = 0

	local function next_register<T>(): Register<T>
		local top = register_top
		if top == MAX_REGISTERS then
			return panic(`Function exceeded {MAX_REGISTERS} registers`)
		end

		register_top += 1

		return {
			__phantom_type = nil :: any,

			type = "id",
			kind = "register",
			index = top,
		}
	end

	local function parameter_id(self: Builder, index: number): types.ParameterId<any>
		if index > n_params then
			return panic(`tried using argument #{index}, but fn only has {n_params} argument(s)`)
		elseif index < 0 then
			return panic(`negative argument id #{index}`)
		end

		return {
			__phantom_type = nil :: any,

			type = "id",
			kind = "parameter",
			index = index,
		}
	end

	local function reserve(self: Builder): Register<any>
		local register = next_register()
		local assign = statement.local_assign(register)
		table.insert(block.statements, assign)
		return register
	end

	local function store<T, R>(self: Builder, value: RValue<T>, into: LValue<R>?): Register<T>
		local statements = block.statements
		if into then
			table.insert(statements, statement.assign(into, value))
			return into :: Register<T>
		end

		local register = next_register(self)
		table.insert(statements, statement.local_assign(register, value))
		return register
	end

	--- Store the result of `value` into `count` registers
	local function store_mult(self: Builder, value: RValue, count: number): { LValue }
		local registers: { LValue } = {}
		for index = 1, count do
			registers[index] = next_register(self)
		end

		local stat = statement.multi_assign(registers, value)
		table.insert(block.statements, stat)

		return registers
	end

	local function allocate(self: Builder, bytes: types.RValue<number>): Register<number>
		local cursor = self:store(globals.outgoing.cursor)
		self:call(control.allocate(bytes) :: any)
		return cursor
	end

	local function call<T>(self: Builder, call: types.ProjCall<T> | types.ProjNamecall<T> | types.CtrlAllocate<T>)
		local stat = statement.call(call)
		table.insert(block.statements, stat)
	end

	local function remark(self: Builder, text: string)
		table.insert(block.statements, statement.remark(text))
	end

	local function term_return(self: Builder, values: { RValue })
		block.terminator = terminator.rtrn(values)
	end

	local function if_single(self: Builder, cond: Condition, body: Constructor)
		local prev_top = register_top
		local truthy_block = next_block(block.scope + 1)
		local falsey_block = next_block(block.scope, block.terminator)

		block.terminator = terminator.if_single(cond, truthy_block, falsey_block, false)
		truthy_block.terminator = terminator.goto(falsey_block)

		--> set block to loop
		block = truthy_block
		table.insert(blocks, truthy_block)

		--> populate the loop
		body(self)

		--> set block to after loop
		block = falsey_block
		register_top = prev_top
		table.insert(blocks, falsey_block)
	end

	local function if_chain(self: Builder, length: number, chain_constructor: IfChainConstructor)
		local scope = block.scope
		local prev_top = register_top
		local after_block = next_block(scope, block.terminator)

		for index = 1, length do
			local truthy_block = next_block(scope + 1)
			local falsey_block = length == index and after_block or next_block(scope, block.terminator)

			local condition, single_constructor = chain_constructor(index)
			block.terminator = terminator.if_chain(condition, truthy_block, falsey_block, index, length)
			truthy_block.terminator = terminator.goto(after_block)

			block = truthy_block
			table.insert(blocks, truthy_block)

			single_constructor(self)

			block = falsey_block
			register_top = prev_top
			table.insert(blocks, falsey_block)
		end

		block = after_block
		register_top = prev_top
		table.insert(blocks, after_block)
	end

	local function for_numeric(self: Builder, iterations: RValue<number>, body: NumericLoopConstructor)
		local prev_top = register_top
		local prev_block = block
		local loop_block = next_block(prev_block.scope + 1)
		local after_block = next_block(prev_block.scope, prev_block.terminator)

		loop_block.terminator = terminator.goto(after_block)

		block = loop_block
		table.insert(blocks, loop_block)

		local index_register = next_register(self) :: Register<number>
		local numeric_loop = loop.numeric(index_register, iterations)
		prev_block.terminator = terminator.loop(numeric_loop, loop_block)

		body(self, index_register)

		block = after_block
		register_top = prev_top
		table.insert(blocks, after_block)
	end

	local function for_generic(self: Builder, target: index<types.LoopGeneric, "target">, body: GenericLoopConstructor)
		local prev_top = register_top
		local prev_block = block
		local loop_block = next_block(prev_block.scope + 1)
		local after_block = next_block(prev_block.scope, prev_block.terminator)

		loop_block.terminator = terminator.goto(after_block)

		block = loop_block
		table.insert(blocks, loop_block)

		local index_register = next_register(self)
		local value_register = next_register(self)
		local numeric_loop = loop.generic(index_register, value_register, target)
		prev_block.terminator = terminator.loop(numeric_loop, loop_block)

		body(self, index_register, value_register)

		block = after_block
		register_top = prev_top
		table.insert(blocks, after_block)
	end

	local function while_loop(self: Builder, condition: Condition, body: Constructor)
		local prev_top = register_top
		local prev_block = block
		local truthy_block = next_block(prev_block.scope + 1)
		local falsey_block = next_block(prev_block.scope, prev_block.terminator)

		prev_block.terminator = terminator.while_loop(condition, truthy_block, falsey_block)
		truthy_block.terminator = terminator.goto(falsey_block)

		--> set block to loop
		block = truthy_block
		table.insert(blocks, truthy_block)

		--> populate the loop
		body(self)

		--> set block to after loop
		block = falsey_block
		register_top = prev_top
		table.insert(blocks, falsey_block)
	end

	local function call_fn(self: Builder, fn_id: FnId, args: { RValue }, rets: { LValue })
		local next_block = next_block(block.scope, block.terminator)
		block.terminator = terminator.call(fn_id, args, rets, next_block)

		block = next_block
		table.insert(blocks, next_block)
	end

	local function capture(self: Builder, upvalues: { Register<any> })
		local max_register = register_top
		for _, upvalue in upvalues do
			max_register = math.max(max_register, upvalue.index)
		end
		register_top = max_register + 1
	end

	local builder: Builder = table.freeze({
		store = store :: any,
		capture = capture,
		reserve = reserve,
		parameter = parameter_id,
		store_mult = store_mult,

		allocate = allocate,

		call = call :: any,
		call_fn = call_fn,

		remark = remark,

		rreturn = term_return,
		if_chain = if_chain,
		if_single = if_single,
		for_numeric = for_numeric,
		for_generic = for_generic,
		while_loop = while_loop,
	})

	constructor(builder)

	for index, bblock in blocks do
		bblock.index = index
	end

	return blocks
end

local function create_fn(name: index<Fn, "name">, params: { Parameter }, rets: { Return }, constructor: Constructor): Fn
	local blocks = construct_fn(#params, constructor)
	return {
		type = "fn",

		id = 0 :: any,
		name = name,

		rets = rets,
		params = params,
		blocks = blocks,
	}
end

local function create_anonymous_fn(params: { Parameter }, rets: { Return }, constructor: Constructor): types.AnonymousFn
	local blocks = construct_fn(#params, constructor)
	return {
		type = "anon_fn",
		rets = rets,
		params = params,
		blocks = blocks,
	}
end

return table.freeze({
	create = create_fn,
	anonymous = create_anonymous_fn,

	rreturn = fn_return,
	parameter = parameter,
})
