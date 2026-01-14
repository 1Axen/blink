local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local literal = require("./literal")
local numeral = require("./numeral")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local panic = require("@util/panic")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

type Axis = ty.Numeral | ty.NumberLiteral

local DEFAULT_AXIS = ty.numeral(nil, "32", "f")

local function to_axes(ctx: Context, ty: ty.Vector): (Axis, Axis, Axis)
	return ty.x or DEFAULT_AXIS, ty.y or DEFAULT_AXIS, ty.z or DEFAULT_AXIS
end

local function read_axis(props: ReadProps, block: Builder, axis_ty: Axis): Register<number>
	if axis_ty.kind == "numeral" then
		return numeral.read(props, block, axis_ty)
	elseif axis_ty.kind == "number_literal" then
		return literal.read(props, block, axis_ty) :: Register<number>
	end

	return panic(`Unexpected vector axis ty kind "{axis_ty.kind}"`)
end

local function write_axis(props: WriteProps, block: Builder, axis_ty: Axis, value: RValue<number>)
	if axis_ty.kind == "numeral" then
		return numeral.write(props, block, axis_ty, value)
	elseif axis_ty.kind == "number_literal" then
		return literal.write(props, block, axis_ty, value :: any)
	end

	panic(`Unexpected vector axis ty kind "{axis_ty.kind}"`)
end

local function validate(block: Builder, vec: ty.Vector, value: RValue<vector>)
	local bounds = vec.magnitude
	if bounds == nil then
		return
	end

	local magnitude = projection.index(value :: any, constant.from_value("magnitude")) :: types.ProjIndex<number>
	if bounds.min == bounds.max then
		local exact_length = constant.from_value(bounds.min)
		local is_exact_length = condition.equals(magnitude, exact_length)
		block:if_single(is_exact_length, function(block)
			local message =
				library.string.format(`Expected vector length to be exactly {bounds.min}, length is %f`, value)
			block:call(library.error_rvalue(message))
		end)

		return
	end

	local lower = condition.less_than(magnitude, constant.from_value(bounds.min))
	local upper = condition.greater_than(magnitude, constant.from_value(bounds.max))

	block:if_single(lower, function(block)
		local message = library.string.format(
			`Expected vector length to be greater than or equal to {bounds.min}, length is %f`,
			value
		)
		block:call(library.error_rvalue(message))
	end)

	block:if_single(upper, function(block)
		local message = library.string.format(
			`Expected vector length to be less than or equal to {bounds.max}, length is %f`,
			value
		)
		block:call(library.error_rvalue(message))
	end)
end

local function build_read(props: ReadProps, block: Builder, vec: ty.Vector, into: LValue<any>?): Register<vector>
	local ty_x, ty_y, ty_z = to_axes(props.ctx, vec)
	local axis_x = read_axis(props, block, ty_x)
	local axis_y = read_axis(props, block, ty_y)
	local axis_z = read_axis(props, block, ty_z)
	local register = block:store(library.vector.create(axis_x, axis_y, axis_z), into)
	validate(block, vec, register)

	return register
end

local function build_write(props: WriteProps, block: Builder, vec: ty.Vector, value: RValue<vector>)
	if props.validate then
		validate(block, vec, value)
	end

	local ty_x, ty_y, ty_z = to_axes(props.ctx, vec)
	write_axis(props, block, ty_x, projection.index(value :: any, constant.from_value("x")))
	write_axis(props, block, ty_y, projection.index(value :: any, constant.from_value("y")))
	write_axis(props, block, ty_z, projection.index(value :: any, constant.from_value("z")))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
