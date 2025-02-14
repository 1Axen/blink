local ty = require("@structures/ty")
local lir = require("@structures/lir")

local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")
local length = require("./length")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type String = ty.String
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, ty: String, attributes: Attributes): Register
    local len: RValue;
    local exact_length = length.is_exact(ty)
    if exact_length then
        len = constant.from_value(exact_length)
    else
        len = length.read(ctx, block, ty, attributes)
    end

    local cursor = control.advance(len)
    return block:store(library.buffer.string.read(cursor, len))
end

local function build_write(ctx: Context, block: Builder, ty: String, attributes: Attributes, at: LValue): ()
    local len: RValue;
    local exact_length = length.is_exact(ty)
    if exact_length then
        len = constant.from_value(exact_length)
    else
        len = block:store(unary.len(at))
        length.write(ctx, block, ty, attributes, len)
    end

    local cursor = block:store(control.allocate(len))
    block:call_lib(library.buffer.string.write(cursor, len, at))
end

local function validate(ctx: Context, block: Builder, ty: String, at: LValue)
    local bounds = ty.length
    if bounds == nil then
        return
    end

    local len = unary.len(at)
    local exact_length = length.is_exact(ty)
    if exact_length then
        local exact = condition.equals(len, constant.from_value(exact_length))
        block:if_branch(exact, function(block)
            block:call_lib(library.error(`Expected string length to be {bounds.min}`))
        end)

        return
    end

    local lower = condition.less_than(len, constant.from_value(bounds.min))
    local upper = condition.greater_than(len, constant.from_value(bounds.max))

    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected string length to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected string length to be less than or equal to {bounds.max}`))
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