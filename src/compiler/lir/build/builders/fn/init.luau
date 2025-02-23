local ty = require("@structures/ty")
local lir = require("@structures/lir")

local panic = require("@util/panic")

local block = require("./block")
local statement = require("./statement")
local terminator = require("./terminator")

local context = require("@lir/build/context")

local loop = require("@builders/loop")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

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
type Register<T = any> = lir.RegisterId<T>

type Context = context.Context

type Body = (block: Builder) -> ()
type NumericLoopBody = (block: Builder, index: Register<number>) -> ()
type GenericLoopBody = (block: Builder, index: Register<any>, value: Register<any>) -> ()

local MAX_REGISTERS = 256
local REGISTERS_TEMPLATE = table.create(MAX_REGISTERS, 0)

for index = 1, MAX_REGISTERS do
    REGISTERS_TEMPLATE[index] = (index - 1)
end

local function returnn(ty: Ty): lir.Return
    return {
        kind = "return",
        ty = ty
    }
end

local function argument(ty: Ty, name: string?): lir.Argument
    return {
        kind = "argument",
        ty = ty,
        name = name
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
        index = index
    }
end

local function next_index(builder: Builder): number
    local index = builder.index
    builder.index += 1
    return index
end

local function store<T>(self: Builder, value: RValue<T>?, into: LValue<T>?): Register<T>
    local register = into or register(self) :: Register<T>
    local assign = statement.assign(register, value)
    table.insert(self.block.statements, assign)
    return register :: Register<T>
end

--- Store the result of `value` into `count` registers
local function store_mult(self: Builder, value: RValue, count: number): {LValue}
    local registers: {LValue} = {}
    for index = 1, count do
        registers[index] = register(self)
    end

    local stat = statement.multi_assign(registers, value)
    table.insert(self.block.statements, stat)

    return registers
end

local function call_lib(self: Builder, projection: lir.ProjCall<any>)
    local call = statement.call(projection)
    table.insert(self.block.statements, call)
end

local function call_fn(self: Builder, ctx: Context, fn_id: FnId, args: {RValue}, rets: number): {LValue}
    -- local call = projection.call(base, args)

    -- local current = self.block
    -- local destination = block.create(current.scope, current.terminator)
    -- current.terminator = terminator.call(fn_id, args, destination)
    
    -- self.block = destination
    -- table.insert(self.blocks, destination)

    error("unimplemented")
end

local function remark(self: Builder, text: string)
    table.insert(self.block.statements, statement.remark(text))
end

local function branch(self: Builder, cond: Condition, body: Body, chained: boolean)
    local current = self.block
    local truthy_block = block.create(next_index(self), current.scope + 1)
    local falsey_block = block.create(next_index(self), current.scope, current.terminator)

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

local function rtrn(self: Builder, values: {RValue})
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
    local loop_block = block.create(next_index(self), prev_block.scope + 1)
    local after_block = block.create(next_index(self), prev_block.scope, prev_block.terminator)

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
    local loop_block = block.create(next_index(self), prev_block.scope + 1)
    local after_block = block.create(next_index(self), prev_block.scope, prev_block.terminator)

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

export type Builder = {
    index: number,
    block: BasicBlock,
    blocks: {BasicBlock},
    registers: {number},

    store: typeof(store),
    store_mult: typeof(store_mult),
    
    --call_fn: typeof(call_fn),
    call_lib: typeof(call_lib),
    
    remark: typeof(remark),
    
    rtrn: typeof(rtrn),
    
    if_branch: typeof(if_branch),
    elseif_branch: typeof(elseif_branch),
    else_branch: typeof(else_branch),
    
    for_numeric: typeof(for_numeric),
    for_generic: typeof(for_generic),

    argument: (self: Builder, index: number) -> lir.ArgumentId<any>
}

local function create(name: string, args: {Argument}, rets: {Return}, body: Body): Fn
    local function argument_id(self: Builder, index: number): lir.ArgumentId<any>
        if index > #args then
            return panic(`Attempted to get argument id #{index}, but fn only has {#args} arguments`)
        elseif index < 0 then
            return panic(`Attempted to get a negative argument id`)
        end

        return {
            __phantom_type = nil :: any,

            type = "id",
            kind = "argument",
            index = index
        }
    end

    local entry = block.create(1)
    local builder: Builder = {
        index = 2,
        block = entry,
        blocks = {entry},
        registers = table.clone(REGISTERS_TEMPLATE),

        store = store,
        store_mult = store_mult,

        call_fn = call_fn,
        call_lib = call_lib,

        remark = remark,
        
        loop = loop,
        rtrn = rtrn,

        if_branch = if_branch,
        elseif_branch = elseif_branch,
        else_branch = else_branch,

        for_numeric = for_numeric,
        for_generic = for_generic,

        argument = argument_id
    }

    --> run the body
    body(builder)

    --> return fn
    return {
        type = "fn",
        name = name,

        rets = rets,
        args = args,
        blocks = builder.blocks,
    }
end

return table.freeze({
    create = create,
    returnn = returnn,
    argument = argument
})