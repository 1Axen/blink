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

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Array = ty.Array
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, array: ty.Array): Register
    local ctx = props.ctx

    local of = hir.ty_from_id(ctx.hir, array.of)
    local len = length.read(props, block, array)
    local array_register = block:store(library.table.create(len))
    
    block:for_numeric(len, function(block, index)
        local element = ty_builder.read(props, block, of)
        local position = projection.field(array_register, index)
        block:store(element, position)
    end)

    return array_register
end

local function build_write(props: WriteProps, block: Builder, array: ty.Array, value: RValue): ()
    local ctx = props.ctx
    local of = hir.ty_from_id(ctx.hir, array.of)

    length.write(props, block, array, unary.len(value))
    block:for_generic(value, function(block, _, value)
        ty_builder.write(props, block, of, value)
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
    read = build_read,
    write = build_write,
})