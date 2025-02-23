local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local numeral = require("./numeral")
local literal = require("./literal")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local panic = require("@util/panic") 

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

type Axis = ty.Numeral | ty.NumberLiteral

local DEFAULT_AXIS = ty.numeral("32", "f")

local function ty_from_id_with_default<T, D>(ctx: Context,ty_id: ty.TyId<T>?, default: D): (T | D)
    if ty_id == nil then
        return default
    end

    return hir.ty_from_id(ctx.hir, ty_id)
end

local function to_axes(ctx: Context, ty: ty.Vector): (Axis, Axis, Axis)
    local ty_x = ty_from_id_with_default(ctx, ty.x, DEFAULT_AXIS)
    local ty_y = ty_from_id_with_default(ctx, ty.y, DEFAULT_AXIS)
    local ty_z = ty_from_id_with_default(ctx, ty.z, DEFAULT_AXIS)
    return ty_x, ty_y, ty_z
end

local function read_axis(props: ReadProps, block: Builder, axis_ty: Axis): Register
    if axis_ty.kind == "numeral" then
        return numeral.read(props, block, axis_ty)
    elseif axis_ty.kind == "number_literal" then
        return literal.read(props, block, axis_ty)
    end

    return panic(`Unexpected vector axis ty kind "{axis_ty.kind}"`)
end

local function write_axis(props: WriteProps, block: Builder, axis_ty: Axis, value: RValue)
    if axis_ty.kind == "numeral" then
        return numeral.write(props, block, axis_ty, value)
    elseif axis_ty.kind == "number_literal" then
        return literal.write(props, block, axis_ty, value)
    end

    panic(`Unexpected vector axis ty kind "{axis_ty.kind}"`)
end

local function build_read(props: ReadProps, block: Builder, ty: ty.Vector): Register
    local ty_x, ty_y, ty_z = to_axes(props.ctx, ty)
    local axis_x = read_axis(props, block, ty_x)
    local axis_y = read_axis(props, block, ty_y)
    local axis_z = read_axis(props, block, ty_z)
    return block:store(library.vector.create(axis_x, axis_y, axis_z))
end

local function build_write(props: WriteProps, block: Builder, ty: ty.Vector, value: RValue)
    local ty_x, ty_y, ty_z = to_axes(props.ctx, ty)
    write_axis(props, block, ty_x, projection.index(value :: LValue, constant.from_value("x")))
    write_axis(props, block, ty_y, projection.index(value :: LValue, constant.from_value("y")))
    write_axis(props, block, ty_z, projection.index(value :: LValue, constant.from_value("z")))
end

local function validate(ctx: Context, block: Builder, ty: ty.Vector, attributes: Attributes, at: LValue)
    local bounds = ty.magnitude
    if bounds == nil then
        return
    end

    local magnitude = projection.index(at, constant.from_value("magnitude"))
    local lower = condition.less_than(magnitude, constant.from_value(bounds.min))
    local upper = condition.greater_than(magnitude, constant.from_value(bounds.max))

    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected vector length to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected vector length to be less than or equal to {bounds.max}`))
    end)
end

return table.freeze({
    read = build_read,
    write = build_write
})