local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local numeral = require("./numeral")
local conversion = require("@util/conversion")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type UnitEnum = ty.UnitEnum
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, enum: UnitEnum, attributes: Attributes): Register
    local total = #enum.variants
    -- account for serdesing from 0
    local format = conversion.to_min_numeral(total - 1)

    local stored_index = numeral.build.read(ctx, block, format, attributes)
    local value_register = block:store()

    local out_of_bounds = condition.greater_than_or(
        stored_index,
        constant.from_value(total)
    )

    block:if_branch(out_of_bounds, function(block)
        block:call_lib(library.error(`Invalid enum variant`))
    end)
    
    for index, variant in enum.variants do
        local is_variant = condition.equals(
            stored_index,
            constant.from_value(index - 1)
        )

        block:elseif_branch(is_variant, function(block)
            block:store(constant.from_value(variant), value_register)
        end)
    end

    return value_register
end

local function build_write(ctx: Context, block: Builder, enum: UnitEnum, attributes: Attributes, at: LValue): ()
    local total = #enum.variants
    -- account for serdesing from 0
    local format = conversion.to_min_numeral(total - 1)
    local index_register = block:store()

    for index, variant in enum.variants do
        local is_variant = condition.equals(
            at,
            constant.from_value(variant)
        )

        local function store_index(block: Builder)
            block:store(constant.from_value(index - 1), index_register)
        end

        if index == 1 then
            block:if_branch(is_variant, store_index)
        elseif index > 1 then
            block:elseif_branch(is_variant, store_index)
        end
    end

    block:else_branch(function(block)
        block:call_lib(library.error(`Invalid enum variant`))
    end)

    numeral.build.write(ctx, block, format, attributes, index_register)
end

local function validate(ctx: Context, block: Builder, enum: UnitEnum, at: LValue)
    
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