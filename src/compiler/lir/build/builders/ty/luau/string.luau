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

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type String = ty.String
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, ty: String): Register
    local len = length.read(props, block, ty)
    local cursor = control.advance(len)
    return block:store(library.buffer.string.read(cursor, len))
end

local function build_write(props: WriteProps, block: Builder, ty: String, value: RValue): ()
    local len = length.write(props, block, ty, unary.len(value))
    local cursor = block:store(control.allocate(len))
    block:call_lib(library.buffer.string.write(cursor, len, value))
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
    read = build_read,
    write = build_write,
})