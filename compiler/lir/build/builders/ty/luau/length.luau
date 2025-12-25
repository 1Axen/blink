local ty = require("@ty")
local types = require("@lir/types")

local attributes = require("@config/attributes")
local bounds = require("@config/bounds")

local binary = require("@builders/binary")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")

local numeral = require("./numeral")

local context = require("@lir/build/context")

local conversion = require("@util/conversion")
local range = require("@util/range")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

local builder_types = require("../builder_types")

type VariableLengthTy = | ty.Map | ty.Array | ty.String | ty.Buffer

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Range = range.Range

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type LValue<T = any> = types.LValue<T>
type RValue<T = any> = types.RValue<T>
type Register<T = any> = types.RegisterId<T>

local function to_range(ty: VariableLengthTy): Range?
	if ty.kind == "buffer" then
		return ty.length
	elseif ty.kind == "string" then
		return ty.length
	elseif ty.kind == "array" then
		return ty.size
	elseif ty.kind == "map" then
		return ty.size
	else
		return strong_exhaustive_match(ty.kind)
	end
end

local function to_max_range(ty: VariableLengthTy): Range
	if ty.kind == "buffer" then
		return bounds.buffer
	elseif ty.kind == "string" then
		return bounds.string
	elseif ty.kind == "array" then
		return bounds.array
	elseif ty.kind == "map" then
		return bounds.map
	else
		return strong_exhaustive_match(ty.kind)
	end
end

local function to_exact_length(ty: VariableLengthTy): number?
	local ty_range = to_range(ty)
	if ty_range == nil then
		return nil
	end

	if ty_range.min ~= ty_range.max then
		return nil
	end

	return ty_range.min
end

--- Returns the numeral and range offset
local function to_relative_range(ty: VariableLengthTy): (ty.Numeral, number)
	local range = to_range(ty) or to_max_range(ty)
	local offset = range.min
	local difference = (range.max - offset)
	return conversion.to_min_numeral(difference), offset
end

local function validate_exact(block: Builder, ty: VariableLengthTy, value: RValue<number>)
	local bounds = to_range(ty)
	if bounds == nil then
		return
	end

	local exact_length = to_exact_length(ty) :: number
	local is_exact_length = condition.equals(value, constant.from_value(exact_length))

	block:if_single(is_exact_length, function(block)
		local message =
			library.string.format(`Expected {ty.kind} length to be exactly {bounds.min}, length is %f`, value)
		block:call(library.error_rvalue(message))
	end)
end

local function validate_range(block: Builder, ty: VariableLengthTy, len_register: LValue<number>)
	local bounds = to_range(ty)
	if bounds == nil then
		return
	end

	local lower = condition.less_than(len_register, constant.from_value(bounds.min))
	local upper = condition.greater_than(len_register, constant.from_value(bounds.max))

	block:if_single(lower, function(block)
		local message = library.string.format(
			`Expected {ty.kind} length to be greater than or equal to {bounds.min}, length is %f`,
			len_register
		)
		block:call(library.error_rvalue(message))
	end)

	block:if_single(upper, function(block)
		local message = library.string.format(
			`Expected {ty.kind} length to be less than or equal to {bounds.max}, length is %f`,
			len_register
		)
		block:call(library.error_rvalue(message))
	end)
end

local function read_length(
	props: ReadProps,
	block: Builder,
	ty: VariableLengthTy
): types.RegisterId<number> | types.Constant<number>
	local exact_length = to_exact_length(ty)
	if exact_length ~= nil then
		return constant.from_value(exact_length)
	end

	local format, offset = to_relative_range(ty)
	local len_register = numeral.read(props, block, format)
	if offset ~= 0 then
		block:store(binary.add(len_register, constant.from_value(offset)), len_register)
	end

	validate_range(block, ty, len_register)

	return len_register
end

local function write_length(
	props: WriteProps,
	block: Builder,
	ty: VariableLengthTy,
	value: RValue<number>
): types.RegisterId<number> | types.Constant<number>
	local exact_length = to_exact_length(ty)
	if exact_length then
		if props.validate then
			validate_exact(block, ty, value)
		end

		return constant.from_value(exact_length)
	end

	local len_register = block:store(value)
	if props.validate then
		validate_range(block, ty, len_register)
	end

	local format, offset = to_relative_range(ty)
	local len_value = len_register
	if offset ~= 0 then
		len_value = binary.sub(len_register, constant.from_value(offset))
	end

	numeral.write(props, block, format, len_value)
	return len_register
end

return table.freeze({
	read = read_length,
	write = write_length,
	is_exact = to_exact_length,
})
