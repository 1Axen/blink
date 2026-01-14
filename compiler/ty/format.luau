local id = require("@compiler/id")
local types = require("./types")

local fmt_range = require("@util/range/format")
local fmt_types = require("@util/format_types")

local range = require("@util/range")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local style = require("@util/style")

local fmt_ty: (ty: types.Ty) -> string
local PRIMITIVE_STYLE = style.color.bright_purple

local function fmt_ty_id<T>(ty_id: types.TyId<T>)
	return id.format(ty_id)
end

local function fmt_opt_range(range: range.Range?): string
	if range == nil then
		return ""
	end

	return fmt_range(range)
end

local function fmt_numeral(ty: types.Numeral): string
	return PRIMITIVE_STYLE(`{ty.format}{ty.size}`) .. fmt_opt_range(ty.bounds)
end

local function fmt_vector(ty: types.Vector): string
	local result = PRIMITIVE_STYLE("vector")
	if ty.x or ty.y or ty.z then
		result ..= "<"

		if ty.x then
			result ..= `{fmt_ty(ty.x)}, `
		end

		if ty.y then
			result ..= `{fmt_ty(ty.y)}, `
		end

		if ty.z then
			result ..= `{fmt_ty(ty.z)}`
		end

		result ..= ">"
	end

	local range = fmt_opt_range(ty.magnitude)
	result ..= range

	return result
end

local function fmt_buffer(ty: types.Buffer): string
	return `{PRIMITIVE_STYLE("buffer")}{fmt_opt_range(ty.length)}`
end

local function fmt_string(ty: types.String): string
	return `{PRIMITIVE_STYLE("string")}{fmt_opt_range(ty.length)}`
end

local function fmt_nil(ty: types.Nil): string
	return PRIMITIVE_STYLE("nil")
end

local function fmt_boolean(ty: types.Boolean): string
	return PRIMITIVE_STYLE(`boolean`)
end

local function fmt_string_literal(ty: types.StringLiteral): string
	return fmt_types.string(ty.value)
end

local function fmt_number_literal(ty: types.NumberLiteral): string
	return fmt_types.number(ty.value)
end

local function fmt_boolean_literal(ty: types.BooleanLiteral): string
	return fmt_types.boolean(ty.value)
end

local function fmt_enum(ty: types.Enum): string
	local result = PRIMITIVE_STYLE("Enum")
	if ty.type then
		result ..= `<{fmt_ty(ty.type)}>`
	end

	return result
end

local function fmt_color3(ty: types.Color3): string
	return PRIMITIVE_STYLE("Color3")
end

local function fmt_cframe(ty: types.CFrame): string
	local result = PRIMITIVE_STYLE("CFrame")
	if ty.position or ty.rotation then
		result ..= "<"

		if ty.position then
			result ..= `{fmt_ty(ty.position)}, `
		end

		if ty.rotation then
			result ..= fmt_ty(ty.rotation)
		end

		result ..= ">"
	end

	return result
end

local function fmt_date_time(ty: types.DateTime): string
	return PRIMITIVE_STYLE("DateTime")
end

local function fmt_date_time_millis(ty: types.DateTimeMillis): string
	return PRIMITIVE_STYLE("DateTimeMillis")
end

local function fmt_brick_color(ty: types.BrickColor): string
	return PRIMITIVE_STYLE("BrickColor")
end

local function fmt_instance(ty: types.Instance): string
	local result = PRIMITIVE_STYLE("Instance")
	if ty.class then
		result ..= `<{fmt_ty(ty.class)}>`
	end

	return result
end

local function fmt_field(ty: types.Field): string
	return `{ty.name}: {fmt_ty(ty.value)}`
end

local function fmt_map(ty: types.Map): string
	return `{PRIMITIVE_STYLE("map")} \{[{fmt_ty(ty.index)}]: {fmt_ty(ty.value)}\}{fmt_opt_range(ty.size)}`
end

local function fmt_array(ty: types.Array): string
	return `[{fmt_ty(ty.of)}]{fmt_opt_range(ty.size)}`
end

local function fmt_union(ty: types.Union): string
	local components = ""
	for index, tty in ty.components do
		if index > 1 then
			components ..= " | "
		end
		components ..= fmt_ty(tty)
	end

	local delimeter_color = style.random_color()
	return `{delimeter_color("(")}{components}{delimeter_color(")")}`
end

local function fmt_struct(ty: types.Struct): string
	local fields: { string } = {}
	for _, field in ty.fields do
		table.insert(fields, fmt_field(field))
	end

	return `{PRIMITIVE_STYLE("struct")} \{{table.concat(fields, ", ")}\}`
end

local function fmt_generic(ty: types.Generic): string
	return `{`@{style.color.black(ty.name)}`}:{fmt_types.number(ty.index)}`
end

local function fmt_discriminated_union(ty: types.DiscriminatedUnion): string
	local variants: { string } = {}
	for _, variant in ty.variants do
		table.insert(variants, `{fmt_ty(variant.key)}: {fmt_struct(variant.value)}`)
	end

	return `{PRIMITIVE_STYLE("enum")} {fmt_types.string(ty.tag)} \{{table.concat(variants, ", ")}\}`
end

local function fmt_unknown(ty: types.Unknown): string
	return PRIMITIVE_STYLE("unknown")
end

local function fmt_reference(ty: types.Reference): string
	local args: { string } = {}
	for _, arg in ty.arguments or {} do
		table.insert(args, fmt_ty(arg))
	end

	return `&{fmt_ty_id(ty.to)}({table.concat(args, ", ")})`
end

local function fmt_type_function(ty: types.TypeFunction): string
	local parameters: { string } = {}
	for _, parameter in ty.parameters do
		table.insert(parameters, fmt_generic(parameter))
	end

	local delimeter_color = style.random_color()
	local open = delimeter_color("(")
	local close = delimeter_color(")")
	return `{open}{table.concat(parameters, ", ")}{close} -> {open}{fmt_ty(ty.body)}{close}`
end

local function fmt_type_instantiation(ty: types.TypeInstantiation): string
	local arguments: { string } = {}
	for _, argument in ty.arguments do
		table.insert(arguments, fmt_ty(argument))
	end

	return `{style.modifer.dim(fmt_ty_id(ty.type_function))}({table.concat(arguments, ", ")})`
end

function fmt_ty(ty: types.Ty): string
	if ty.kind == "map" then
		return fmt_map(ty)
	elseif ty.kind == "nil" then
		return fmt_nil(ty)
	elseif ty.kind == "array" then
		return fmt_array(ty)
	elseif ty.kind == "struct" then
		return fmt_struct(ty)
	elseif ty.kind == "discriminated_union" then
		return fmt_discriminated_union(ty)
	elseif ty.kind == "union" then
		return fmt_union(ty)
	elseif ty.kind == "blocked" then
		return "*blocked*"
	elseif ty.kind == "generic" then
		return fmt_generic(ty)
	elseif ty.kind == "type_function" then
		return fmt_type_function(ty)
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
	elseif ty.kind == "streamed_instance" then
		return fmt_instance(ty :: any)
	elseif ty.kind == "date_time" then
		return fmt_date_time(ty)
	elseif ty.kind == "date_time_millis" then
		return fmt_date_time_millis(ty)
	elseif ty.kind == "brick_color" then
		return fmt_brick_color(ty)
	elseif ty.kind == "unknown" then
		return fmt_unknown(ty)
	elseif ty.kind == "reference" then
		return fmt_reference(ty)
	elseif ty.kind == "type_instantiation" then
		return fmt_type_instantiation(ty)
	else
		return strong_exhaustive_match(ty.kind)
	end
end

return fmt_ty
