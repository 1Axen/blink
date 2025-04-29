local ty = require("@ty/types")
local hir = require("@hir/types")

local range = require("@util/range")
local panic = require("@util/panic")

local md5 = require("@vendor/md5")

type Ty = ty.Ty
type Hir = hir.Hir

local hash_ty: (owner: Hir, ty: Ty) -> string

local function hash_ty_id<T>(owner: Hir, ty_id: ty.TyId<T>): string
    local ty = hir.ty_from_id(owner, ty_id)
    return hash_ty(owner, ty)
end

local function hash_range(range: range.Range?): string
    return if range then 
        `range({range.min}..{range.max})` 
        else ""
end

local function hash_numeral(owner: Hir, ty: ty.Numeral): string
    return `numeral({ty.format}{ty.size}):{hash_range(ty.bounds)}`
end

local function hash_vector(owner: Hir, ty: ty.Vector): string
    local generics = ""
    if ty.x then
        generics ..= `{hash_ty_id(owner, ty.x)},`
    end
    if ty.y then
        generics ..= `{hash_ty_id(owner, ty.y)},`
    end
    if ty.z then
        generics ..= `{hash_ty_id(owner, ty.z)},`
    end

    return `vector({generics}):{hash_range(ty.magnitude)}`
end

local function hash_buffer(owner: Hir, ty: ty.Buffer): string
    return `buffer():{hash_range(ty.length)}`
end

local function hash_string(owner: Hir, ty: ty.String): string
    return `string():{hash_range(ty.length)}`
end

local function hash_boolean(owner: Hir, ty: ty.Boolean): string
    return `boolean()`
end

local function hash_string_literal(owner: Hir, ty: ty.StringLiteral): string
    return `string_literal()`
end

local function hash_number_literal(owner: Hir, ty: ty.NumberLiteral): string
    return `number_literal()`
end

local function hash_boolean_literal(owner: Hir, ty: ty.BooleanLiteral): string
    return `boolean_literal()`
end

local function hash_enum(owner: Hir, ty: ty.Enum): string
    local generics = if ty.type then hash_ty_id(owner, ty.type) else ""
    return `enum({generics})`
end

local function hash_color3(ty: ty.Color3): string
    return `color3()`
end

local function hash_cframe(owner: Hir, ty: ty.CFrame): string
    local generics = ""
    if ty.position then
        generics ..= `{hash_ty_id(owner, ty.position)},`
    end
    if ty.rotation then
        generics ..= `{hash_ty_id(owner, ty.rotation)},`
    end
    return `cframe({generics})`
end

local function hash_date_time(owner: Hir, ty: ty.DateTime): string
    return `date_time()`
end

local function hash_date_time_millis(owner: Hir, ty: ty.DateTimeMillis): string
    return `date_time_millis()`
end

local function hash_brick_color(owner: Hir, ty: ty.BrickColor): string
    return `brick_color()`
end

local function hash_instance(owner: Hir, ty: ty.Instance): string
    local generics = if ty.class then hash_ty_id(owner, ty.class) else ""
    return `instance({generics})`
end

local function hash_field(owner: Hir, ty: ty.Field): string
    return `field({ty.name}, {hash_ty_id(owner, ty.value)})`
end

local function hash_set(owner: Hir, ty: ty.Set): string
    local items: {string} = {}
    for index, item in ty.items do
        items[index] = item.value
    end
    return `set({table.concat(items, ",")})`
end

local function hash_map(owner: Hir, ty: ty.Map): string
    return `map({hash_ty_id(owner, ty.index)}, {hash_ty_id(owner, ty.value)}):{hash_range(ty.size)}`
end

local function hash_array(owner: Hir, ty: ty.Array): string
    return `array({hash_ty_id(owner, ty.of)}):{hash_range(ty.size)}`
end

local function hash_intersection(owner: Hir, ty: ty.Intersection): string
    return `intersection({hash_ty_id(owner, ty.left)}, {hash_ty_id(owner, ty.right)})`
end

local function hash_struct(owner: Hir, ty: ty.Struct): string
    local fields: {string} = {}
    for index, field in ty.fields do
        fields[index] = hash_field(owner, field)
    end
    return `struct({table.concat(fields, ",")})`
end

local function hash_optional(owner: Hir, ty: ty.Optional): string
    return `optional({hash_ty_id(owner, ty.of)})`
end

local function hash_generic(owner: Hir, ty: ty.Generic): string
    return `generic({ty.name}, {ty.index})`
end

local function hash_unit_enum(owner: Hir, ty: ty.UnitEnum): string
    return `unit_enum({table.concat(ty.variants, ",")})`
end

local function hash_variant(owner: Hir, ty: ty.Variant): string
    return `variant({hash_ty_id(owner, ty.key)}, {hash_struct(owner, ty.value)})`
end

local function hash_tagged_enum(owner: Hir, ty: ty.TaggedEnum): string
    local variants: {string} = {}
    for index, variant in ty.variants do
        variants[index] = hash_variant(owner, variant)
    end
    return `tagged_enum({ty.tag}, {table.concat(variants, ",")})`
end

local function hash_unknown(owner: Hir, ty: ty.Unknown): string
    return "unknown()"
end

local function hash_placeholder(owner: Hir, ty: ty.Placeholder): string
    local args: {string} = {}
    if ty.args then
        for index, arg in ty.args do
            args[index] = hash_ty_id(owner, arg)
        end
    end

    return `placeholder({table.concat(ty.path, ".")},{table.concat(args, ",")})`
end

local function hash_generic_type(owner: Hir, ty: ty.GenericType): string
    local args: {string} = {}
    for index, arg in ty.args do
        args[index] = hash_ty_id(owner, arg)
    end

    -- Generic types share the same def under the hood
    -- If the def is different then we can assume the type is not the same
    local address = tostring(ty.def)
    
    return `generic_type({address},{table.concat(args, ",")})`
end

function hash_ty(owner: Hir, ty: ty.Ty): string
    local hash: string;
	if ty.kind == "set" then
		hash = hash_set(owner, ty)
	elseif ty.kind == "map" then
		hash = hash_map(owner, ty)
	elseif ty.kind == "array" then
		hash = hash_array(owner, ty)
	elseif ty.kind == "struct" then
		hash = hash_struct(owner, ty)
	elseif ty.kind == "optional" then
		hash = hash_optional(owner, ty)
	elseif ty.kind == "unit_enum" then
		hash = hash_unit_enum(owner, ty)
	elseif ty.kind == "tagged_enum" then
		hash = hash_tagged_enum(owner, ty)
    elseif ty.kind == "intersection" then
        hash = hash_intersection(owner, ty)
	elseif ty.kind == "generic" then
		hash = hash_generic(owner, ty :: ty.Generic)
    elseif ty.kind == "placeholder" then
        hash = hash_placeholder(owner, ty)
	elseif ty.kind == "generic_type" then
		hash = hash_generic_type(owner, ty :: ty.GenericType)
	elseif ty.kind == "numeral" then
		hash = hash_numeral(owner, ty)
	elseif ty.kind == "string" then
		hash = hash_string(owner, ty :: ty.String)
	elseif ty.kind == "buffer" then
		hash = hash_buffer(owner, ty)
    elseif ty.kind == "vector" then
        hash = hash_vector(owner, ty :: ty.Vector)
    elseif ty.kind == "boolean" then
        hash = hash_boolean(owner, ty)
    elseif ty.kind == "string_literal" then
        hash = hash_string_literal(owner, ty :: ty.StringLiteral)
    elseif ty.kind == "number_literal" then
		hash = hash_number_literal(owner, ty)
    elseif ty.kind == "boolean_literal" then
		hash = hash_boolean_literal(owner, ty :: ty.BooleanLiteral)
    elseif ty.kind == "roblox_enum" then
        hash = hash_enum(owner, ty)
    elseif ty.kind == "cframe" then
        hash = hash_cframe(owner, ty :: ty.CFrame)
    elseif ty.kind == "color3" then
        hash = hash_color3(ty)
    elseif ty.kind == "instance" then
        hash = hash_instance(owner, ty :: ty.Instance)
    elseif ty.kind == "date_time" then
        hash = hash_date_time(owner, ty)
    elseif ty.kind == "date_time_millis" then
        hash = hash_date_time_millis(owner, ty)
    elseif ty.kind == "brick_color" then
        hash = hash_brick_color(owner, ty)
    elseif ty.kind == "unknown" then
        hash = hash_unknown(owner, ty)
    else
        return panic(`Unhandled ty kind {ty.kind}`)
    end

    return (md5(hash))
end

return hash_ty