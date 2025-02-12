local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local types = require("./types")
local context = require("@lir/build/context")

local panic = require("@util/panic")

local ty_set = require("./luau/set")
local ty_map = require("./luau/map")
local ty_array = require("./luau/array")
local ty_struct = require("./luau/struct")
local ty_optional = require("./luau/optional")
local ty_unit_enum = require("./luau/unit_enum")
local ty_tagged_enum = require("./luau/tagged_enum")
local ty_generic_type = require("./luau/generic_type")

local ty_buffer = require("./luau/buffer")
local ty_string = require("./luau/string")
local ty_vector = require("./luau/vector")
local ty_literal = require("./luau/literal")
local ty_numeral = require("./luau/numeral")
local ty_boolean = require("./luau/boolean")

local ty_enum = require("./roblox/enum")
local ty_cframe = require("./roblox/cframe")
local ty_color3 = require("./roblox/color3")
local ty_unknown = require("./roblox/unknown")
local ty_instance = require("./roblox/instance")
local ty_date_time = require("./roblox/date_time")
local ty_brick_color = require("./roblox/brick_color")
local ty_date_time_millis = require("./roblox/date_time_millis")

type Ty = ty.Ty
type LValue = lir.LValue
type Register = lir.RegisterId

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type TyBuilder = types.TyBuilder

local BUILDERS: {[ty.TyKind]: TyBuilder?} = {
    set = ty_set,
    map = ty_map,
    array = ty_array,
    union = ty_struct,
    struct = ty_struct,
    optional = ty_optional,
    unit_enum = ty_unit_enum,
    tagged_enum = ty_tagged_enum,
    generic_type = ty_generic_type,

    buffer = ty_buffer,
    string = ty_string,
    vector = ty_vector,
    literal = ty_literal,
    numeral = ty_numeral,
    boolean = ty_boolean,

    cframe = ty_cframe,
    color3 = ty_color3,
    unknown = ty_unknown,
    instance = ty_instance,
    date_time = ty_date_time,
    brick_color = ty_brick_color,
    roblox_enum = ty_enum,
    date_time_millis = ty_date_time_millis,
} 

local function as_builder(ty: Ty): TyBuilder
    local ty_builder = BUILDERS[ty.kind]
    if ty_builder == nil then
        return panic(`Unhandled ty kind: "{ty.kind}"`)
    end

    return ty_builder
end

local function build_read(ctx: Context, block: Builder, ty: Ty, attributes: Attributes): Register
    local ty_builder = as_builder(ty)
    return ty_builder.build.read(ctx, block, ty, attributes)
end

local function build_write(ctx: Context, block: Builder, ty: Ty, attributes: Attributes, at: LValue): ()
    local ty_builder = as_builder(ty)
    return ty_builder.build.write(ctx, block, ty, attributes, at)
end

local function validate_read(ctx: Context, block: Builder, ty: Ty, at: LValue)
    local ty_builder = as_builder(ty)
    return ty_builder.validate.read(ctx, block, ty, at)
end

local function validate_write(ctx: Context, block: Builder, ty: Ty, at: LValue)
    local ty_builder = as_builder(ty)
    return ty_builder.validate.write(ctx, block, ty, at)
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate_read,
        write = validate_write
    })
})