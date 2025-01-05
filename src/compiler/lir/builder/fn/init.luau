local lir = require("@compiler/structures/lir")

local panic = require("@util/panic")

local block = require("./block")
local statement = require("./statement")
local terminator = require('./terminator')

type Fn = lir.Fn
type FnId = lir.FnId

type Return = lir.Return
type Argument = lir.Argument

type Register = lir.RegisterId
type BasicBlock = lir.BasicBlock

type Loop = lir.Loop
type Condition = lir.Condition

type Value = lir.Value
type LValue = lir.LValue
type LRValue = lir.LRValue

type Body = (Builder) -> ()

local MAX_REGISTERS = 256
local REGISTERS_TEMPLATE = table.create(MAX_REGISTERS, 0)

for index = 1, MAX_REGISTERS do
    REGISTERS_TEMPLATE[index] = (index - 1)
end

local function register(self: Builder): Register
    local index = table.remove(self.registers, 1)
    if index == nil then
        return panic(`Function exceeded {MAX_REGISTERS} registers`)
    end

    return {
        kind = "register",
        index = index
    }
end

local function store(self: Builder, into: Register?, value: Value?): Register
    local register = into or register(self)
    local assign = statement.assign(register, value)
    table.insert(self.block.statements, assign)
    return register
end

local function call_lib(self: Builder, projection: lir.ProjCall)
    local call = statement.call(projection)
    table.insert(self.block.statements, call)
end

local function call_fn(self: Builder, fn: FnId, args: {Value})
    local current = self.block
    local destination = block.create(current.scope, current.terminator)
    current.terminator = terminator.call(fn, args, destination)
    
    self.block = destination
    table.insert(self.blocks, destination)
end

local function loop(self: Builder, loop: Loop, body: Body)
    local current = self.block
    local loop_block = block.create(current.scope + 1)
    local after_block = block.create(current.scope, current.terminator)

    current.terminator = terminator.loop(loop, loop_block)
    loop_block.terminator = terminator.goto(after_block)

    --> set block to loop
    self.block = loop_block
    table.insert(self.blocks, loop_block)

    --> populate the loop
    body(self)

    --> set block to after loop
    self.block = after_block
    table.insert(self.blocks, after_block)
end

local function ifbr(self: Builder, cond: Condition, body: Body)
    local current = self.block
    local truthy_block = block.create(current.scope + 1)
    local falsey_block = block.create(current.scope, current.terminator)

    current.terminator = terminator.ifbr(cond, truthy_block, falsey_block)
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

local function rtrn(self: Builder, values: {Value})
    local current = self.block
    if current.terminator.kind ~= "none" then
        panic("Early return")
    end

    current.terminator = terminator.rtrn(values)
end

type Builder = {
    block: BasicBlock,
    blocks: {BasicBlock},
    registers: {number},

    store: typeof(store),
    
    call_fn: typeof(call_fn),
    call_lib: typeof(call_lib)

    loop: typeof(loop),
    rtrn: typeof(rtrn),
    ifbr: typeof(ifbr),
}

local function create(name: string, args: {Argument}, rets: {Return}, body: Body): Fn
    local entry = block.create()
    local builder: Builder = {
        block = entry,
        blocks = {entry},
        registers = table.clone(REGISTERS_TEMPLATE),

        store = store,

        call_fn = call_fn,
        call_lib = call_lib,
        
        loop = loop,
        rtrn = rtrn,
        ifbr = ifbr,
    }

    --> run the body
    body(builder)

    --> return fn
    return {
        kind = "fn",
        name = name,

        rets = rets,
        args = args,
        blocks = builder.blocks,
    }
end

return table.freeze({
    create = create
})