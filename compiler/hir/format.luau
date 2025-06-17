local hir = require("@hir/types")
local id = require("@compiler/id")
local ty = require("@ty/types")

local fmt_id = require("@compiler/id/format")
local fmt_ty = require("@ty/format")
local fmt_types = require("@util/format_types")

local span = require("@util/span")
local string_builder = require("@util/string_builder")
local style = require("@util/style")

local FIELD_STYLE = style.modifer.dim
local IDENT_STYLE = style.color.yellow
local CATEGORY_STYLE = style.combine(style.color.bright_white, style.modifer.bold)
local ATTRIBUTE_STYLE = style.color.bright_purple

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

local function fmt_parameters(parameters: { hir.Parameter }, fmt_builder: StringBuilder)
	string_builder.append(fmt_builder, "(")

	for index, parameter in parameters do
		if parameter.name then
			string_builder.append(fmt_builder, `{FIELD_STYLE(parameter.name)}: `)
		end

		string_builder.append(fmt_builder, fmt_id(parameter.value))

		if index < #parameters then
			string_builder.append(fmt_builder, ", ")
		end
	end

	string_builder.append(fmt_builder, ")")
end

local function fmt_type(decl: hir.Type, fmt_builder: StringBuilder)
	fmt_attributes(decl.attributes, fmt_builder)

	string_builder.append(fmt_builder, `{CATEGORY_STYLE("Type")} \{\n`)
	string_builder.indent(fmt_builder)

	string_builder.append_line(fmt_builder, `{FIELD_STYLE("name:")} {fmt_types.string(decl.name)},`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("scope:")} {fmt_id(decl.scope)},`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("ty:")} {fmt_id(decl.ty)},`)

	if decl.generics then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("generics:")} \{`)

		for index, generic in decl.generics do
			string_builder.append(fmt_builder, fmt_id(generic :: ty.TyId))

			if #decl.generics > index then
				string_builder.append(fmt_builder, ", ")
			end
		end

		string_builder.append(fmt_builder, "}\n")
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_event(decl: hir.Event, fmt_builder: StringBuilder)
	fmt_attributes(decl.attributes, fmt_builder)

	string_builder.append(fmt_builder, `{CATEGORY_STYLE("Event")} \{\n`)
	string_builder.indent(fmt_builder)

	string_builder.append_line(fmt_builder, `{FIELD_STYLE("name:")} {decl.name}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("from:")} {IDENT_STYLE(decl.from)}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("type:")} {IDENT_STYLE(decl.type)}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("call:")} {IDENT_STYLE(decl.call)}`)
	string_builder.append_line(fmt_builder, `{FIELD_STYLE("poll:")} {fmt_types.boolean(decl.poll)}`)

	if decl.data then
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, `{FIELD_STYLE("data:")} `)
		fmt_parameters(decl.data, fmt_builder)
		string_builder.append(fmt_builder, "\n")
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_function(decl: hir.Function, fmt_builder: StringBuilder)
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

local function fmt_tys(hirr: hir.Hir, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Tys")} \{`)
	string_builder.indent(fmt_builder)

	local tys = hirr.tys
	local sorted: { ty.TyId } = {}

	for ty_id in tys do
		table.insert(sorted, ty_id)
	end

	table.sort(sorted, function(a, b)
		return a < b
	end)

	for _, ty_id in sorted do
		local ty = tys[ty_id]
		local node_id = id.ty_id.to_node_id(ty_id)
		local ty_node = hir.node_from_id(hirr, node_id)

		local source_code = span.value(ty_node.span)
		local as_lines = string.split(source_code, "\n")

		string_builder.append_indent(fmt_builder)
		string_builder.append_line(fmt_builder, `{fmt_id(ty_id)}: {fmt_ty(ty)}`)

		string_builder.indent(fmt_builder)
		string_builder.indent(fmt_builder)
		string_builder.append_lines(fmt_builder, as_lines)
		string_builder.dedent(fmt_builder)
		string_builder.dedent(fmt_builder)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_decls(decls: { [hir.DeclId]: hir.Decl }, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Decls")} \{`)
	string_builder.indent(fmt_builder)

	for decl_id, decl in decls do
		string_builder.append_indent(fmt_builder)
		string_builder.append(fmt_builder, fmt_id(decl_id))
		string_builder.append(fmt_builder, ": ")

		if decl.kind == "type" then
			fmt_type(decl, fmt_builder)
		elseif decl.kind == "event" then
			fmt_event(decl, fmt_builder)
		elseif decl.kind == "function" then
			fmt_function(decl, fmt_builder)
		end
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_scopes(scopes: { [hir.ScopeId]: string }, fmt_builder: StringBuilder)
	string_builder.append_line(fmt_builder, `{CATEGORY_STYLE("Scopes")} \{`)
	string_builder.indent(fmt_builder)

	for scope_id, scope_name in scopes do
		string_builder.append_line(fmt_builder, `{fmt_id(scope_id)}: {fmt_types.string(scope_name)}`)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_hir(hir: hir.Hir): string
	local fmt_builder = string_builder.create()

	fmt_tys(hir, fmt_builder)
	fmt_decls(hir.decls, fmt_builder)
	fmt_scopes(hir.scopes, fmt_builder)

	return string_builder.finalize(fmt_builder)
end

return fmt_hir
