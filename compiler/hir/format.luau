local ast = require("@ast")
local fmt_types = require("@util/format_types")
local id = require("@compiler/id")
local lookup = require("./lookup")
local span = require("@util/span")
local string_builder = require("@util/string_builder")
local style = require("@util/style")
local ty = require("@ty")
local types = require("@hir/types")

local FIELD_STYLE = style.modifer.dim
local IDENT_STYLE = style.color.yellow
local CATEGORY_STYLE = style.combine(style.color.bright_white, style.modifer.bold)
local ATTRIBUTE_STYLE = style.color.bright_purple

type Hir = types.Hir
type StringBuilder = string_builder.StringBuilder

local function fmt_attributes(attributes: any, fmt_builder: StringBuilder)
	for name, value in attributes do
		string_builder.append(fmt_builder, ATTRIBUTE_STYLE(`@{name}`))

		if value ~= true then
			string_builder.append(
				fmt_builder,
				`{ATTRIBUTE_STYLE("(")}{fmt_types.any(value :: any)}{ATTRIBUTE_STYLE(")")}`
			)
		end

		string_builder.append(fmt_builder, " ")
	end
end

local function fmt_parameters(parameters: { types.Parameter }, fmt_builder: StringBuilder)
	string_builder.append(fmt_builder, "(")

	for index, parameter in parameters do
		if parameter.name then
			string_builder.append(fmt_builder, `{FIELD_STYLE(parameter.name)}: `)
		end

		string_builder.append(fmt_builder, id.format(parameter.ty_id))

		if index < #parameters then
			string_builder.append(fmt_builder, ", ")
		end
	end

	string_builder.append(fmt_builder, ")")
end

local function fmt_type(decl: types.Type, fmt_builder: StringBuilder)
	fmt_attributes(decl.attributes, fmt_builder)

	string_builder.append(fmt_builder, `{CATEGORY_STYLE("Type")} \{\n`)
	string_builder.indent(fmt_builder)

	string_builder.append_line(fmt_builder, `{FIELD_STYLE("name:")} {fmt_types.string(decl.name)},`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("scope:")} {id.format(decl.scope_id)},`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("ty:")} {id.format(decl.ty_id)},`)

	if decl.generics then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("generics:")} \{`)

		for index, generic in decl.generics do
			string_builder.append(fmt_builder, ty.format(generic))

			if #decl.generics > index then
				string_builder.append(fmt_builder, ", ")
			end
		end

		string_builder.append(fmt_builder, "}\n")
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_event(decl: types.Event, fmt_builder: StringBuilder)
	fmt_attributes(decl.attributes, fmt_builder)

	string_builder.append(fmt_builder, `{CATEGORY_STYLE("Event")} \{\n`)
	string_builder.indent(fmt_builder)

	string_builder.append_line(fmt_builder, `{FIELD_STYLE("name:")} {decl.name}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("from:")} {IDENT_STYLE(decl.from)}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("type:")} {IDENT_STYLE(decl.type)}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("call:")} {IDENT_STYLE(decl.call)}`)

	if decl.data then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("data:")} `)
		fmt_parameters(decl.data, fmt_builder)
		string_builder.append(fmt_builder, "\n")
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_function(decl: types.Function, fmt_builder: StringBuilder)
	fmt_attributes(decl.attributes, fmt_builder)

	string_builder.append(fmt_builder, `{CATEGORY_STYLE("Function")} \{\n`)
	string_builder.indent(fmt_builder)

	string_builder.append_line(fmt_builder, `{FIELD_STYLE("name:")} {decl.name}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("yield:")} {IDENT_STYLE(decl.yield)}`)

	if decl.data then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("data:")} `)
		fmt_parameters(decl.data, fmt_builder)
		string_builder.append(fmt_builder, "\n")
	end

	if decl.ret then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("return:")} `)
		fmt_parameters(decl.ret, fmt_builder)
		string_builder.append(fmt_builder, "\n")
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_tys(hirr: Hir, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Tys")} \{`)
	string_builder.indent(fmt_builder)

	local tys = hirr.tys
	local sorted: { ty.TyId } = {}

	for ty_id in tys do
		table.insert(sorted, ty_id)
	end

	table.sort(sorted, function(a: number, b: number)
		return a < b
	end)

	for _, ty_id in sorted do
		local tty = tys[ty_id]
		local node_id = ty_id :: ast.NodeId
		local ty_node = lookup.node_from_id(hirr, node_id)

		local source_code = span.value(ty_node.span)
		local as_lines = string.split(source_code, "\n")

		string_builder.append_indent(fmt_builder)
		string_builder.append_line(fmt_builder, `{id.format(ty_id)}: {ty.format(tty)}`)

		string_builder.indent(fmt_builder)
		string_builder.indent(fmt_builder)
		string_builder.append_lines(fmt_builder, as_lines)
		string_builder.dedent(fmt_builder)
		string_builder.dedent(fmt_builder)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_decls(hirr: Hir, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Decls")} \{`)
	string_builder.indent(fmt_builder)

	for decl_id, decl in hirr.types do
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, id.format(decl_id))
		string_builder.append(fmt_builder, ": ")
		fmt_type(decl, fmt_builder)
	end

	for decl_id, decl in hirr.events do
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, id.format(decl_id))
		string_builder.append(fmt_builder, ": ")
		fmt_event(decl, fmt_builder)
	end

	for decl_id, decl in hirr.functs do
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, id.format(decl_id))
		string_builder.append(fmt_builder, ": ")
		fmt_function(decl, fmt_builder)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_scopes(scopes: index<Hir, "scopes">, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Scopes")} \{`)
	string_builder.indent(fmt_builder)

	for scope_id, scope in scopes do
		string_builder.append_line(fmt_builder, `{id.format(scope_id)}: {fmt_types.string(scope.name)}`)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_hir(hirr: Hir): string
	local fmt_builder = string_builder.create({})

	fmt_tys(hirr, fmt_builder)
	fmt_decls(hirr, fmt_builder)
	fmt_scopes(hirr.scopes, fmt_builder)

	return string_builder.finalize(fmt_builder)
end

return fmt_hir
