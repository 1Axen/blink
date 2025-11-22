local span = require("@util/span")
local types = require("./types")

local fmt_statement
local fmt_expression

local function fmt_range(node: types.Range): string
	local expr_min = node.min
	local expr_max = node.max

	local min = expr_min and tostring(expr_min.value) or ""
	local max = expr_max and tostring(expr_max.value) or ""

	return `({min}..{max})`
end

local function fmt_generic(node: types.GenericDef): string
	local name = node.name
	return `{name.value}`
end

local function fmt_generics(node: types.GenericsDef): string
	local strings = {}
	for _, generic in node.values do
		table.insert(strings, fmt_generic(generic))
	end

	return `<{table.concat(strings, ", ")}>`
end

local function fmt_segment(node: types.PathSegment): string
	return node.value
end

local function fmt_path(node: types.Path): string
	local path = ""
	local indices = #node.segments

	for index, segment in node.segments do
		path ..= fmt_segment(segment)
		if index < indices then
			path ..= "."
		end
	end

	return path
end

local function fmt_identifier(node: types.Identifier): string
	return node.value
end

local function fmt_union(expr: types.ExprUnion): string
	local stringified = ""
	for index, component_expr in expr.components do
		if index > 1 then
			stringified ..= " | "
		end

		stringified ..= fmt_expression(component_expr)
	end

	return stringified
end

function fmt_expression(expr: types.Expression): string
	if expr.kind == "set" then
		return "set { ... }"
	elseif expr.kind == "map" then
		return "map { ... }"
	elseif expr.kind == "enum" then
		return "enum { ... }"
	elseif expr.kind == "union" then
		return fmt_union(expr)
	elseif expr.kind == "struct" then
		return "struct { ... }"
	elseif expr.kind == "string" then
		return `"{expr.value}"`
	elseif expr.kind == "number" then
		return tostring(expr.value)
	elseif expr.kind == "array" then
		return `{fmt_expression((expr :: types.ExprArray).value)}[]`
	elseif expr.kind == "boolean" then
		return tostring((expr :: types.ExprBoolean).value)
	elseif expr.kind == "optional" then
		return `{fmt_expression((expr :: types.ExprOptional).value)}?`
	elseif expr.kind == "tagged_enum" then
		return `enum "{fmt_expression((expr :: types.ExprTaggedEnum).tag)}" \{ ... \}`
	elseif expr.kind == "reference" then
		return fmt_path(expr.path)
	end

	error("unreachable")
end

function fmt_statement(stat: types.Statement): string
	if stat.kind == "type" then
		local name = stat.name :: types.Identifier
		local generics = stat.generics
		return `{fmt_identifier(name)}{if generics then fmt_generics(generics) else ""}`
	end

	error("unreachable")
end

local function fmt_node(node: types.Node): string
	return `"{span.value(node.span)}" ({node.span.z}:{node.span.x}..{node.span.y})`
end

return table.freeze({
	node = fmt_node,
	range = fmt_range,
	generic = fmt_generic,
	generics = fmt_generics,
	segment = fmt_segment,
	path = fmt_path,
	identifier = fmt_identifier,
	expression = fmt_expression,
	statement = fmt_statement,
})
