local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local numeral = require("./numeral")
local conversion = require("@util/conversion")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type UnitEnum = ty.UnitEnum
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, enum: UnitEnum): Register<string>
    local total = #enum.variants
    -- account for serdesing from 0
    local format = conversion.to_min_numeral(total - 1)

    local stored_index = numeral.read(props, block, format)
    local value_register = block:reserve() :: Register<string>

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

local function build_write(props: WriteProps, block: Builder, enum: UnitEnum, value: RValue<string>): ()
    local total = #enum.variants
    -- account for serdesing from 0
    local format = conversion.to_min_numeral(total - 1)

    for index, variant in enum.variants do
        local is_variant = condition.equals(
            value,
            constant.from_value(variant)
        )

        local function write_index(block: Builder)
            numeral.write(props, block, format, constant.from_value(index - 1))
        end

        if index == 1 then
            block:if_branch(is_variant, write_index)
        elseif index > 1 then
            block:elseif_branch(is_variant, write_index)
        end
    end

    block:else_branch(function(block)
        block:call_lib(library.error(`Invalid enum variant`))
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})