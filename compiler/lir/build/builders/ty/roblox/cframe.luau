local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local ty_vector = require("../luau/vector")

local binary = require("@builders/binary")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
local numeral = require("@builders/ty/luau/numeral")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

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

local mul = binary.mul
local cos = library.math.cos
local sin = library.math.sin

local const = constant.from_value

local HALF = const(0.5)
local VECTOR = ty.vector({})
local DEFAULT_FORMAT = ty.numeral("32", "f")

local function square(value: RValue<number>)
	return mul(value, value)
end

local function to_tys(ctx: Context, cframe_ty: ty.CFrame): (ty.Vector, ty.Vector)
	local pos_ty = if cframe_ty.position
		then ty.vector({
			x = cframe_ty.position,
			y = cframe_ty.position,
			z = cframe_ty.position,
		})
		else VECTOR

	local rot_ty: ty.Vector = if cframe_ty.rotation
		then ty.vector({
			x = cframe_ty.rotation,
			y = cframe_ty.rotation,
			z = cframe_ty.rotation,
		})
		else VECTOR

	return pos_ty, rot_ty
end

local function build_read(props: ReadProps, block: Builder, cframe_ty: ty.CFrame, into: LValue<any>?): Register<CFrame>
	local position_ty = cframe_ty.position or DEFAULT_FORMAT
	local rotation_ty = cframe_ty.rotation or DEFAULT_FORMAT

	local position_x = numeral.read(props, block, position_ty)
	local position_y = numeral.read(props, block, position_ty)
	local position_z = numeral.read(props, block, position_ty)

	local axis_x = numeral.read(props, block, rotation_ty)
	local axis_y = numeral.read(props, block, rotation_ty)
	local axis_z = numeral.read(props, block, rotation_ty)

	local dot = binary.add(square(axis_x), binary.add(square(axis_y), square(axis_z)))
	local magnitude = block:store(library.math.sqrt(dot))

	local store_location = (into or block:reserve()) :: Register<CFrame>
	block:if_chain(2, function(index: number)
		if index == 1 then
			return condition.equals(magnitude, constant.zero),
				function(block: Builder)
					local value = library.CFrame.new_position(position_x, position_y, position_z)
					block:store(value, store_location)
				end
		end

		return condition.equals(constant.truth, constant.truth),
			function(block: Builder)
				local inverse_magnitude = block:store(binary.div(constant.one, magnitude))

				local half_angle = block:store(binary.mul(magnitude, HALF))
				local sin_angle = block:store(sin(half_angle))

				local cframe_ctor = library.CFrame.new_quat(
					position_x,
					position_y,
					position_z,
					mul(mul(axis_x, inverse_magnitude), sin_angle),
					mul(mul(axis_y, inverse_magnitude), sin_angle),
					mul(mul(axis_z, inverse_magnitude), sin_angle),
					cos(half_angle)
				)

				block:store(cframe_ctor, store_location)
			end
	end)

	return store_location
end

local function build_write(props: WriteProps, block: Builder, cframe_ty: ty.CFrame, value: RValue<CFrame>): ()
	local pos_ty, rot_ty = to_tys(props.ctx, cframe_ty)

	-- position
	local position = block:store(projection.index(value :: any, const("Position"))) :: Register<vector>
	ty_vector.write(props, block, pos_ty, position)

	-- rotation
	local axis_angle = block:store_mult(library.CFrame.to_axis_angle(value) :: any, 2) :: { Register<number> }
	local rotation = block:store(binary.mul_vec(axis_angle[1] :: any, axis_angle[2]))
	ty_vector.write(props, block, rot_ty, rotation)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
