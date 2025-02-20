local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local length = require("./length")
local ty_builder = require("@builders/ty")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Array = ty.Array
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, array: Array, attributes: Attributes): Register
    local of = hir.ty_from_id(ctx.hir, array.of)
    local len = length.read(ctx, block, array, attributes)
    local array_register = block:store(library.table.create(len))
    
    block:for_numeric(len, function(block, index)
        local value_register = ty_builder.build.read(ctx, block, of, attributes)
        local array_index = projection.field(array_register, index)
        block:store(value_register, array_index)
    end)

    return block:store()
end

local function build_write(ctx: Context, block: Builder, array: Array, attributes: Attributes, at: LValue): ()
    local of = hir.ty_from_id(ctx.hir, array.of)

    length.write(ctx, block, array, attributes, unary.len(at))
    block:for_generic(at, function(block, index, value)
        ty_builder.build.write(ctx, block, of, attributes, value)
    end)
end

local function validate(ctx: Context, block: Builder, array: Array, at: LValue)
    local bounds = array.size
    if bounds == nil then
        return
    end

    local len = unary.len(at)
    local exact_length = length.is_exact(array)
    if exact_length then
        local exact = condition.equals(len, constant.from_value(exact_length))
        block:if_branch(exact, function(block)
            block:call_lib(library.error(`Expected array size to be {bounds.min}`))
        end)

        return
    end

    local lower = condition.less_than(len, constant.from_value(bounds.min))
    local upper = condition.greater_than(len, constant.from_value(bounds.max))

    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected array size to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected array size to be less than or equal to {bounds.max}`))
    end)
end

local function validate_read(ctx: Context, block: Builder, array: Array, at: LValue)
    if length.is_exact(array) then
        return
    end

    validate(ctx, block, array, at)
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate_read,
        write = validate
    })
})