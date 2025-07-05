local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local conversion = require("@util/conversion")
local numeral = require("./numeral")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type UnitEnum = ty.UnitEnum
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, enum: UnitEnum, into: LValue<any>?)
	local total = #enum.variants
	-- account for serdesing from 0
	local format = conversion.to_min_numeral(total - 1)

	local stored_index = numeral.read(props, block, format)
	local value_register = (into or block:reserve()) :: Register<string>

	local within_bounds = condition.less_than_or(stored_index, constant.from_value(total))
	block:call_lib(library.assert(within_bounds, "Invalid enum variant"))

	for index, variant in enum.variants do
		local is_variant = condition.equals(stored_index, constant.from_value(index - 1))

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
		local is_variant = condition.equals(value, constant.from_value(variant))

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
