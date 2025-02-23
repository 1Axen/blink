local ty = require("@structures/ty")
local lir = require("@structures/lir")
local hir = require("@structures/hir")
local attributes = require("@config/attributes")

local ty_vector = require("../luau/vector")
local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local binary = require('@builders/binary')
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type CFrame = ty.CFrame
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local add = binary.add
local sub = binary.sub
local mul = binary.mul

local cos = library.math.cos
local sin = library.math.sin

local const = constant.from_value

local HALF = const(0.5)
local POS_FORMAT = ty.vector({})
local ROT_FORMAT = ty_numeral.f32

local function to_tys(ctx: Context, cframe_ty: CFrame): (ty.Vector, ty.Numeral)
    local pos_ty = if cframe_ty.position 
    then ty.vector({
        x = cframe_ty.position, 
        y = cframe_ty.position, 
        z = cframe_ty.position
    }) 
    else POS_FORMAT

    local rot_ty: ty.Numeral = if cframe_ty.rotation 
        then hir.ty_from_id(ctx.hir, cframe_ty.rotation) 
        else ROT_FORMAT

    return pos_ty, rot_ty
end

local function build_read(props: ReadProps, block: Builder, cframe_ty: CFrame): Register
    local pos_ty, rot_ty = to_tys(props.ctx, cframe_ty)

    local pos = ty_vector.read(props, block, pos_ty)
    local rot_x = ty_numeral.read(props, block, rot_ty)
    local rot_y = ty_numeral.read(props, block, rot_ty)
    local rot_z = ty_numeral.read(props, block, rot_ty)

    local cos_x = block:store(cos(mul(rot_x, HALF)))
    local sin_x = block:store(sin(mul(rot_x, HALF)))
    local cos_y = block:store(cos(mul(rot_y, HALF)))
    local sin_y = block:store(sin(mul(rot_y, HALF)))
    local cos_z = block:store(cos(mul(rot_z, HALF)))
    local sin_z = block:store(sin(mul(rot_z, HALF)))

    local cos_x_sin_y = mul(cos_x, sin_y)
    local cos_x_cos_y = mul(cos_x, cos_y)
    local sin_x_sin_y = mul(sin_x, sin_y)
    local sin_x_cos_y = mul(sin_x, cos_y)

    local cframe_ctor = library.CFrame.new_quat(
        projection.index(pos, const("x")), 
        projection.index(pos, const("y")), 
        projection.index(pos, const("z")),
        -- sin_x * cos_y * cos_z + cos_x * sin_y * sin_z
        add(
            mul(sin_x_cos_y, cos_z),
            mul(cos_x_sin_y, sin_z)
        ), 
        -- cos_x * sin_y * cos_z - sin_x * cos_y * sin_z
        sub(
            mul(cos_x_sin_y, cos_z),
            mul(sin_x_cos_y, sin_z)
        ), 
        -- cos_x * cos_y * sin_z + sin_x * sin_y * cos_z
        add(
            mul(cos_x_cos_y, sin_z),
            mul(sin_x_sin_y, cos_z)
        ),
        -- cos_x * cos_y * cos_z - sin_x * sin_y * sin_z
        add(
            mul(cos_x_cos_y, cos_z),
            mul(sin_x_sin_y, sin_z)
        )
    )

    return block:store(cframe_ctor)
end

local function build_write(props: WriteProps, block: Builder, cframe_ty: CFrame, value: RValue): ()
    local pos_ty, rot_ty = to_tys(props.ctx, cframe_ty)
    
    -- position
    ty_vector.write(props, block, pos_ty, value)

    -- rotation
    local to_euler = projection.namecall(value :: LValue, const("ToEulerAnglesXYZ"), {})
    local rotation_axes = block:store_mult(to_euler, 3)

    ty_numeral.write(props, block, rot_ty, rotation_axes[1])
    ty_numeral.write(props, block, rot_ty, rotation_axes[2])
    ty_numeral.write(props, block, rot_ty, rotation_axes[3])
end

return table.freeze({
    read = build_read,
    write = build_write,
})