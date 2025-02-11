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
local PRIMITIVE_STYLE = style.color.bright_purple

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
    return PRIMITIVE_STYLE(`{ty.format}{ty.size}`) .. fmt_opt_range(ty.bounds)
end

local function fmt_vector(ty: ty.Vector): string
    local result = PRIMITIVE_STYLE("vector")
    if ty.x or ty.y or ty.z then
        result ..= "<"

        if ty.x then
            result ..= `{fmt_id(ty.x)}, `
        end

        if ty.y then
            result ..= `{fmt_id((ty :: any).y :: any)}, `
        end

        if ty.z then
            result ..= `{fmt_id((ty :: any).z :: any)}`
        end

         result ..= ">"
    end

    local range = fmt_opt_range(ty.magnitude)
    result ..= range

    return result
end

local function fmt_buffer(ty: ty.Buffer): string
    return `{PRIMITIVE_STYLE("buffer")}{fmt_opt_range(ty.length)}`
end

local function fmt_string(ty: ty.String): string
    return `{PRIMITIVE_STYLE("string")}{fmt_opt_range(ty.length)}`
end

local function fmt_boolean(ty: ty.Boolean): string
    return PRIMITIVE_STYLE(`boolean`)
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
    local result = PRIMITIVE_STYLE("Enum")
    if ty.type then
        result ..= `<{fmt_id(ty.type)}>`
    end

    return result
end

local function fmt_color3(ty: ty.Color3): string
    return PRIMITIVE_STYLE("Color3")
end

local function fmt_cframe(ty: ty.CFrame): string
    local result = PRIMITIVE_STYLE("CFrame")
    if ty.position or ty.rotation then
        result ..= "<"

        if ty.position then
            result ..= `{fmt_id(ty.position)}, `
        end

        if ty.rotation then
            result ..= fmt_id((ty :: any).rotation :: any)
        end

        result ..= ">"
    end

    return result
end

local function fmt_date_time(ty: ty.DateTime): string
    return PRIMITIVE_STYLE("DateTime")
end

local function fmt_date_time_millis(ty: ty.DateTimeMillis): string
    return PRIMITIVE_STYLE("DateTimeMillis")
end

local function fmt_brick_color(ty: ty.BrickColor): string
    return PRIMITIVE_STYLE("BrickColor")
end

local function fmt_instance(ty: ty.Instance): string
    local result = PRIMITIVE_STYLE("Instance")
    if ty.class then
        result ..= `<{fmt_id(ty.class)}>`
    end

    return result
end

local function fmt_field(ty: ty.Field): string
    return `{ty.name}: {fmt_id(ty.value)}`
end

local function fmt_set(ty: ty.Set): string
    local items = {}
    for index, literal in ty.items do
        items[index] = literal.value    
    end

    return `{PRIMITIVE_STYLE("set")} \{"{table.concat(items, "\", ")}"\}`
end

local function fmt_map(ty: ty.Map): string
    return `{PRIMITIVE_STYLE("map")} \{[{fmt_id(ty.index)}]: {fmt_id(ty.value)}\}{fmt_opt_range(ty.range)}`
end

local function fmt_array(ty: ty.Array): string
    return `\{{fmt_id(ty.of)}\}{fmt_range(ty.size)}`
end

local function fmt_union(ty: ty.Union): string
    return `{fmt_id(ty.left)} & {fmt_id(ty.right)}`
end

local function fmt_struct(ty: ty.Struct): string
    local fields: {string} = {}
    for _, field in ty.fields do
        table.insert(fields, fmt_field(field))
    end

    return `{PRIMITIVE_STYLE("struct")} \{{table.concat(fields, ", ")}\}`
end

local function fmt_optional(ty: ty.Optional): string
    return `{fmt_id(ty.of)}?`
end

local function fmt_generic(ty: ty.Generic): string
    return `{`@{style.color.black(ty.name)}`}:{fmt_types.number(ty.index)}`
end

local function fmt_unit_enum(ty: ty.UnitEnum): string
    return `{PRIMITIVE_STYLE("enum")} \{{table.concat(ty.variants, ", ")}\}`
end

local function fmt_tagged_enum(ty: ty.TaggedEnum): string
    local variants: {string} = {}
    for _, variant in ty.variants do
        table.insert(variants, `{fmt_types.any(variant.key)}: {fmt_struct(variant.value)}`)
    end

    return `{PRIMITIVE_STYLE("enum")} {fmt_types.string(ty.tag)} \{{table.concat(variants, ", ")}\}`
end

local function fmt_unknown(ty: ty.Unknown): string
    return PRIMITIVE_STYLE("unknown")
end

local function fmt_placeholder(ty: ty.Placeholder): string
    local args: {string} = {}
    for _, arg in ty.args or {} do
        table.insert(args, fmt_id(arg))
    end

    return `{style.color.black(`@{table.concat(ty.path, ".")}`)}<{table.concat(args, ", ")}>`
end

local function fmt_generic_type(ty: ty.GenericType): string
    local args: {string} = {}
    for _, arg in ty.args do
        table.insert(args, fmt_id(arg))
    end

    return `{PRIMITIVE_STYLE("GT")} ({style.modifer.dim(fmt_ty(ty.def))}, \{{table.concat(args, ", ")}\})`
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
	elseif ty.kind == "unit_enum" then
		return fmt_unit_enum(ty)
	elseif ty.kind == "tagged_enum" then
		return fmt_tagged_enum(ty)
	elseif ty.kind == "generic" then
		return fmt_generic(ty :: ty.Generic)
    elseif ty.kind == "placeholder" then
        return fmt_placeholder(ty)
	elseif ty.kind == "generic_type" then
		return fmt_generic_type(ty :: ty.GenericType)
	elseif ty.kind == "numeral" then
		return fmt_numeral(ty)
	elseif ty.kind == "string" then
		return fmt_string(ty :: ty.String)
	elseif ty.kind == "buffer" then
		return fmt_buffer(ty)
    elseif ty.kind == "vector" then
        return fmt_vector(ty :: ty.Vector)
    elseif ty.kind == "boolean" then
        return fmt_boolean(ty)
    elseif ty.kind == "string_literal" then
        return fmt_string_literal(ty :: ty.StringLiteral)
    elseif ty.kind == "number_literal" then
		return fmt_number_literal(ty)
    elseif ty.kind == "boolean_literal" then
		return fmt_boolean_literal(ty :: ty.BooleanLiteral)
    elseif ty.kind == "roblox_enum" then
        return fmt_enum(ty)
    elseif ty.kind == "cframe" then
        return fmt_cframe(ty :: ty.CFrame)
    elseif ty.kind == "color3" then
        return fmt_color3(ty)
    elseif ty.kind == "instance" then
        return fmt_instance(ty :: ty.Instance)
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