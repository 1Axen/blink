local ty = require("@structures/ty")
local lir = require("@structures/lir")

local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local context = require("@lir/build/context")

local panic = require("@util/panic")

local types = require("./types")

local ty_set = require("./luau/set")
local ty_unit_enum = require("./luau/unit_enum")

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
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

-- cyclical ty builders
local ty_map: TyBuilder?;
local ty_array: TyBuilder?;
local ty_struct: TyBuilder?;
local ty_optional: TyBuilder?;
local ty_tagged_enum: TyBuilder?;
local ty_generic_type: TyBuilder?;
local ty_intersection: TyBuilder?;

local BUILDERS: {[ty.TyKind]: TyBuilder?} = {
    set = ty_set,
    unit_enum = ty_unit_enum,

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

local function replace_generic(props: ReadProps | WriteProps, ty: Ty): Ty
    if ty.kind ~= "generic" then
        return ty
    end

    local generics = props.generics
    if generics == nil then
        return panic(`Tried to get builder for generic, but there are no generics`)
    end
    
    return generics[ty.index]
end

local function builder_from_ty(ty: Ty): TyBuilder
    local kind = ty.kind
    if kind == "map" then
        if ty_map == nil then
            ty_map = (require :: any)("./luau/map")
        end
        return ty_map
    elseif kind == "array" then
        if ty_array == nil then
            ty_array = (require :: any)("./luau/array")
        end
        return ty_array
    elseif kind == "struct" then
        if ty_struct == nil then
            ty_struct = (require :: any)("./luau/struct")
        end
        return ty_struct
    elseif kind == "optional" then
        if ty_optional == nil then
            ty_optional = (require :: any)("./luau/optional")
        end
        return ty_optional
    elseif kind == "tagged_enum" then
        if ty_tagged_enum == nil then
            ty_tagged_enum = (require :: any)("./luau/tagged_enum")
        end
        return ty_tagged_enum
    elseif kind == "generic_type" then
        if ty_generic_type == nil then
            ty_generic_type = (require :: any)("./luau/generic_type")
        end
        return ty_generic_type
    elseif kind == "intersection" then
        if ty_intersection == nil then
            ty_intersection = (require :: any)("./luau/intersection")
        end
        return ty_intersection
    end

    local ty_builder = BUILDERS[kind]
    if ty_builder == nil then
        return panic(`Unhandled ty kind: "{ty.kind}"`)
    end

    return ty_builder
end

local function build_read(props: ReadProps, block: Builder, ty: Ty): Register<any>
    ty = replace_generic(props, ty)
    
    local ty_builder = builder_from_ty(ty)
    return ty_builder.read(props, block, ty)
end

local function build_write(props: WriteProps, block: Builder, ty: Ty, value: RValue<any>): ()
    ty = replace_generic(props, ty)

    local ty_builder = builder_from_ty(ty)
    return ty_builder.write(props, block, ty, value)
end

return table.freeze({
    read = build_read,
    write = build_write
})