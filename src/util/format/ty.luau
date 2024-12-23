local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")

local fmt_id = require("@format/id")
local fmt_types = require("@format/types")
local fmt_range = require("@format/range")

local id = require("@compiler/id")

local style = require("@util/style")
local range = require("@util/range")
local panic = require("@util/panic")

local fmt_ty: (ty: ty.Ty) -> string

local function fmt_opt_id(opt_id: id.Id?): string
    if opt_id == nil then
        return ""
    end

    return fmt_id(opt_id)
end

local function fmt_opt_range(range: range.Range?): string
    if range == nil then
        return ""
    end

    return fmt_range(range)
end

local function fmt_numeral(ty: ty.Numeral): string
    return `{ty.format}{ty.size}{fmt_opt_range(ty.bounds)}`
end

local function fmt_vector(ty: ty.Vector): string
    local range = fmt_opt_range(ty.magnitude)

    if ty.z and ty.y and ty.x then
        return `vector<{fmt_id(ty.x)},{fmt_id(ty.y)},{fmt_id(ty.z)}>{range}`
    elseif ty.y and ty.x then
        return `vector<{fmt_id(ty.x)},{fmt_id(ty.y)}>{range}`
    elseif ty.x then
        return `vector<{fmt_id(ty.x)}>{range}`
    end

    return `vector{range}`
end

local function fmt_buffer(ty: ty.Buffer): string
    return `buffer{fmt_opt_range(ty.length)}`
end

local function fmt_string(ty: ty.String): string
    return `string{fmt_opt_range(ty.length)}`
end

local function fmt_boolean(ty: ty.Boolean): string
    return `boolean`
end

local function fmt_string_literal(ty: ty.StringLiteral): string
    return fmt_types.string(ty.value)
end

local function fmt_number_literal(ty: ty.NumberLiteral): string
    return fmt_types.number(ty.value)
end

local function fmt_boolean_literal(ty: ty.BooleanLiteral): string
    return fmt_types.boolean(ty.value)
end

local function fmt_enum(ty: ty.Enum): string
    if ty.type then
        return `Enum<{fmt_id(ty.type)}>`
    end

    return `Enum`
end

local function fmt_color3(ty: ty.Color3): string
    return `Color3`
end

local function fmt_cframe(ty: ty.CFrame): string
    if ty.rotation and ty.position then
        return `CFrame<{fmt_id(ty.position)},{fmt_id(ty.rotation)}>`
    elseif ty.position then
        return `CFrame<{fmt_id(ty.position)}>`
    end

    return `CFrame`
end

local function fmt_date_time(ty: ty.DateTime): string
    return `DateTime`
end

local function fmt_date_time_millis(ty: ty.DateTimeMillis): string
    return `DateTimeMillis`
end

local function fmt_brick_color(ty: ty.BrickColor): string
    return `BrickColor`
end

local function fmt_instance(ty: ty.Instance): string
    if ty.class then
        return `Instance<{fmt_id(ty.class)}>`
    end

    return `Instance`
end

local function fmt_field(ty: ty.Field): string
    return `{ty.name}: {fmt_id(ty.value)}`
end

local function fmt_set(ty: ty.Set): string
    return `set \{"{table.concat(ty.items, "\", ")}"\}`
end

local function fmt_map(ty: ty.Map): string
    return `map \{[{fmt_id(ty.index)}]: {fmt_id(ty.value)}\}{fmt_opt_range(ty.range)}`
end

local function fmt_array(ty: ty.Array): string
    return `array {fmt_id(ty.of)} {fmt_range(ty.size)}`
end

local function fmt_union(ty: ty.Union): string
    return `union {fmt_id(ty.left)} & {fmt_id(ty.right)}`
end

local function fmt_struct(ty: ty.Struct): string
    local fields: {string} = {}
    for _, field in ty.fields do
        table.insert(fields, fmt_field(field))
    end

    return `struct \{{table.concat(fields, ", ")}\}`
end

local function fmt_optional(ty: ty.Optional): string
    return `optional {fmt_id(ty.of)}`
end

local function fmt_placeholder(ty: ty.Placeholder): string
    return `{style.color.cyan(ty.name)}@{fmt_types.number(ty.index)}`
end

local function fmt_unit_enum(ty: ty.UnitEnum): string
    return `enum \{"{table.concat(ty.variants, "\", ")}"\}`
end

local function fmt_tagged_enum(ty: ty.TaggedEnum): string
    local variants: {string} = {}
    for _, variant in ty.variants do
        table.insert(variants, `{fmt_types.any(variant.key)}: {fmt_struct(variant.value)}`)
    end

    return `enum {fmt_types.string(ty.tag)} \{{table.concat(variants, ", ")}\}`
end

local function fmt_unknown(ty: ty.Unknown): string
    return `unknwon`
end

local function fmt_generic_type(ty: ty.GenericType): string
    local args: {string} = {}
    for _, arg in ty.args do
        table.insert(args, fmt_id(arg))
    end

    return `generic ({style.modifer.dim(fmt_ty(ty.ty))}) <{table.concat(args, ", ")}>`
end

function fmt_ty(ty: ty.Ty): string
	if ty.kind == "set" then
		return fmt_set(ty)
	elseif ty.kind == "map" then
		return fmt_map(ty)
	elseif ty.kind == "array" then
		return fmt_array(ty)
	elseif ty.kind == "union" then
		return fmt_union(ty)
	elseif ty.kind == "struct" then
		return fmt_struct(ty)
	elseif ty.kind == "optional" then
		return fmt_optional(ty)
	elseif ty.kind == "enum" then
		return fmt_unit_enum(ty)
	elseif ty.kind == "tagged_enum" then
		return fmt_tagged_enum(ty)
	elseif ty.kind == "placeholder" then
		return fmt_placeholder(ty)
	elseif ty.kind == "generic_type" then
		return fmt_generic_type(ty)
	elseif ty.kind == "numeral" then
		return fmt_numeral(ty)
	elseif ty.kind == "string" then
		return fmt_string(ty)
	elseif ty.kind == "buffer" then
		return fmt_buffer(ty)
    elseif ty.kind == "vector" then
        return fmt_vector(ty)
    elseif ty.kind == "boolean" then
        return fmt_boolean(ty)
    elseif ty.kind == "string_literal" then
        return fmt_string_literal(ty)
    elseif ty.kind == "number_literal" then
		return fmt_number_literal(ty)
    elseif ty.kind == "boolean_literal" then
		return fmt_boolean_literal(ty)
    elseif ty.kind == "roblox_enum" then
        return fmt_enum(ty)
    elseif ty.kind == "cframe" then
        return fmt_cframe(ty)
    elseif ty.kind == "color3" then
        return fmt_color3(ty)
    elseif ty.kind == "instance" then
        return fmt_instance(ty)
    elseif ty.kind == "date_time" then
        return fmt_date_time(ty)
    elseif ty.kind == "date_time_millis" then
        return fmt_date_time_millis(ty)
    elseif ty.kind == "brick_color" then
        return fmt_brick_color(ty)
    elseif ty.kind == "unknown" then
        return fmt_unknown(ty)
    end

    return panic(`Unhandled ty kind {ty.kind}`)
end

return fmt_ty