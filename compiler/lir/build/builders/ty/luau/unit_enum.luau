local attributes = require("@config/attributes")
local builder_types = require("../builder_types")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@lir/build/context")
local conversion = require("@util/conversion")
local fn = require("@builders/fn")
local hir = require("@hir")
local library = require("@builders/library")
local numeral = require("./numeral")
local ty = require("@ty")
local types = require("@lir/types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type UnitEnum = ty.UnitEnum
type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, enum: UnitEnum, into: LValue<any>?)
	local hhir = props.ctx.hir
	local variants = enum.variants
	local variants_count = #variants
	-- account for serdesing from 0
	local format = conversion.to_min_numeral(variants_count - 1)

	local value = (into or block:reserve()) :: Register<string>
	local stored_value = numeral.read(props, block, format)

	block:if_chain(variants_count + 1, function(index)
		if index > variants_count then
			local fallback = condition.equals(constant.truth, constant.truth)
			return fallback, function(block: Builder)
				block:call(library.error("Invalid enum variant"))
			end
		end

		local variant_ty = hir.ty_from_id(hhir, variants[index]) :: any
		local variant_index = constant.from_value(index - 1)
		local variant_value = constant.from_ty(variant_ty)

		local is_variant = condition.equals(stored_value, variant_index)
		return is_variant, function(block: Builder)
			block:store(variant_value, value)
		end
	end)

	return value
end

local function build_write(props: WriteProps, block: Builder, enum: UnitEnum, value: RValue<string>): ()
	local hhir = props.ctx.hir
	local variants = enum.variants
	local variants_count = #variants
	-- account for serdesing from 0
	local format = conversion.to_min_numeral(variants_count - 1)

	block:if_chain(variants_count + 1, function(index)
		if index > variants_count then
			local fallback = condition.equals(constant.truth, constant.truth)
			return fallback, function(block: Builder)
				block:call(library.error("Invalid enum variant"))
			end
		end

		local variant_ty = hir.ty_from_id(hhir, variants[index]) :: any
		local variant_index = constant.from_value(index - 1)

		local variant_value = constant.from_ty(variant_ty)
		local is_variant = condition.equals(value, variant_value)

		return is_variant, function(block: Builder)
			numeral.write(props, block, format, variant_index)
		end
	end)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
