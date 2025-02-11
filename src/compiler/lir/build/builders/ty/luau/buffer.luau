local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local length = require("./length")
local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Buffer = ty.Buffer
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, ty: Buffer, attributes: Attributes): Register
    local exact_length = length.is_exact(ty)
    if exact_length then
        local bytes = constant.from_value(exact_length)
        local advance = control.advance(bytes)
        local buffer_read = library.buffer.string.read(advance, bytes)
        return block:store(buffer_read)
    end

    local len = length.read(ty)
    local advance = control.advance(len)
    local buffer_read = library.buffer.string.read(advance, len)

    return block:store(buffer_read)
end

local function build_write(ctx: Context, block: Builder, ty: Buffer, attributes: Attributes, at: LValue): ()
    local exact_length = length.is_exact(ty)
    if exact_length then
        local bytes = constant.from_value(exact_length)
        local allocate = block:store(control.advance(bytes))
        local buffer_copy = library.buffer.copy(at, constant.zero, bytes)
        block:call_lib(buffer_copy)
        return
    end

    local len = unary.len(at)
    local allocate = block:store(control.allocate(len))

    local size = length.write(block, ty, at)
    local buffer_copy = library.buffer.copy(at, constant.zero, len)
    
    block:call_lib(buffer_copy)
end

local function validate(ctx: Context, block: Builder, ty: Buffer, at: LValue)
    local bounds = ty.length
    if bounds == nil then
        return
    end

    local len = unary.len(at)
    local lower = condition.less_than(len, constant.from_value(bounds.min))
    local upper = condition.greater_than(len, constant.from_value(bounds.max))

    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected buffer length to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected buffer length to be less than or equal to {bounds.max}`))
    end)
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate,
        write = validate
    })
})