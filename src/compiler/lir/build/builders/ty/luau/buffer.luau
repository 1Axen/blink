local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local globals = require("@builders/globals")
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
    local len = length.read(ctx, block, ty, attributes)
    local register = block:store(library.buffer.create(len))
    local buffer_copy = library.buffer.copy(
        register, constant.zero, 
        globals.incoming.buffer, control.advance(len), len
    )

    block:call_lib(buffer_copy)
    return register
end

local function build_write(ctx: Context, block: Builder, ty: Buffer, attributes: Attributes, at: LValue): ()
    local len = length.write(ctx, block, ty, attributes, library.buffer.len(at))
    local cursor = block:store(control.allocate(len))
    local buffer_copy = library.buffer.copy(
        globals.outgoing.buffer, cursor, 
        at, constant.zero, len
    )

    block:call_lib(buffer_copy)
end

local function validate(ctx: Context, block: Builder, ty: Buffer, at: LValue)
    local bounds = ty.length
    if bounds == nil then
        return
    end

    local len = unary.len(at)
    local exact_length = length.is_exact(ty)
    if exact_length then
        local exact = condition.equals(len, constant.from_value(exact_length))
        block:if_branch(exact, function(block)
            block:call_lib(library.error(`Expected buffer length to be {bounds.min}`))
        end)

        return
    end

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