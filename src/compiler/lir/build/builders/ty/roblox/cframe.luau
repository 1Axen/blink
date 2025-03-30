local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local ty_vector = require("../luau/vector")

local fn = require("@builders/fn")
local binary = require('@builders/binary')
local library = require("@builders/library")
local constant = require("@builders/constant")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local mul = binary.mul
local cos = library.math.cos
local sin = library.math.sin

local const = constant.from_value

local HALF = const(0.5)
local VECTOR = ty.vector({})

local function index_vector(vec: RValue<vector>, property: "x" | "y" | "z"): lir.ProjIndex<number>
    return projection.index(vec :: any, const(property :: string)) :: lir.ProjIndex<number>
end

local function to_tys(ctx: Context, cframe_ty: ty.CFrame): (ty.Vector, ty.Vector)
    local pos_ty = 
        if cframe_ty.position 
        then ty.vector({
            x = cframe_ty.position, 
            y = cframe_ty.position, 
            z = cframe_ty.position
        }) 
        else VECTOR

    local rot_ty: ty.Vector = 
        if cframe_ty.rotation 
        then ty.vector({
            x = cframe_ty.rotation, 
            y = cframe_ty.rotation, 
            z = cframe_ty.rotation
        }) 
        else VECTOR

    return pos_ty, rot_ty
end

local function build_read(props: ReadProps, block: Builder, cframe_ty: ty.CFrame): Register<CFrame>
    local pos_ty, rot_ty = to_tys(props.ctx, cframe_ty)

    local pos = ty_vector.read(props, block, pos_ty)
    local axis_angle = ty_vector.read(props, block, rot_ty)

    local angle = block:store(library.vector.magnitude(axis_angle))
    -- div specifies RValue<number> but you can also div vectors
    -- div can't be typed correctly as RValue<number | vector>
    -- because of solver limitations
    local axis = block:store(binary.div_vec(axis_angle, angle))

    local half_angle = block:store(binary.mul(angle, HALF))
    local sin_angle = block:store(sin(half_angle))

    local cframe_ctor = library.CFrame.new_quat(
        index_vector(pos, "x"),
        index_vector(pos, "y"),
        index_vector(pos, "z"),
        mul(index_vector(axis, "x"), sin_angle),
        mul(index_vector(axis, "y"), sin_angle),
        mul(index_vector(axis, "z"), sin_angle),
        cos(half_angle)
    )

    return block:store(cframe_ctor)
end

local function build_write(props: WriteProps, block: Builder, cframe_ty: ty.CFrame, value: RValue<CFrame>): ()
    local pos_ty, rot_ty = to_tys(props.ctx, cframe_ty)
    
    -- position
    local position = block:store(projection.index(value :: any, const("Position"))) :: Register<vector>
    ty_vector.write(props, block, pos_ty, position)

    -- rotation
    local axis_angle = block:store_mult(library.CFrame.to_axis_angle(value) :: any, 3) :: {Register<number>}
    local rotation = block:store(binary.mul_vec(axis_angle[1] :: any, axis_angle[2]))
    ty_vector.write(props, block, rot_ty, rotation)
end

return table.freeze({
    read = build_read,
    write = build_write,
})