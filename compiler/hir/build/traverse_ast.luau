local ast = require("@ast")
local attributes = require("./attributes")
local options = require("@config/options")
local panic = require("@util/panic")
local report = require("@hir/report")
local store_node = require("./store_node")
local symbols = require("@compiler/symbols")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type Decl = types.Decl
type Node = ast.Node
type Hir = types.Hir
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId<T>
type DeclId = types.DeclId
type NodeId = ast.NodeId
type ScopeId = types.ScopeId

type Symbols = ast.Symbols

type Context = {
	read hir: Hir,
	read options: options.FileOptions,
	read options_declarations: { [string]: ast.StatOption },

	symbols: Symbols,
	scope_id: ScopeId,
}

export type Collection = {
	read types: { types.Type },
	read events: { types.Event },
	read functs: { types.Function },
}

local function assert_identifier_one_of(ident: ast.Identifier, valid: { string }): ast.Identifier
	local value = ident.value
	if table.find(valid, value) == nil then
		return report.expect_one_of(ident, valid, value)
	end

	return ident
end

local function stat_type(ctx: Context, stat: ast.StatType): types.Type
	--> lower generics
	local parameters: { ty.Generic }?
	if stat.generics then
		parameters = {}

		for index, node in stat.generics.values do
			store_node(ctx.hir, node)

			local name = node.name.value
			local generic = ty.generic(node :: any, name, index)
			parameters[index] = generic
		end
	end

	--> lower expression
	local node_id = store_node(ctx.hir, stat)

	return {
		id = node_id :: DeclId,
		kind = "type",
		name = stat.name.value,
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),

		ty_id = node_id :: TyId,
		generics = parameters,
	}
end

local function stat_event(ctx: Context, stat: ast.StatEvent): types.Event
	local name = stat.name.value
	local from = assert_identifier_one_of(stat.from, { "Client", "Server", "Both" }).value :: index<types.Event, "from">
	local call = assert_identifier_one_of(
		stat.call,
		{ "ManySync", "SingleSync", "ManyAsync", "SingleAsync", "Polling" }
	).value :: index<types.Event, "call">
	local reliability =
		assert_identifier_one_of(stat.type, { "Reliable", "Unreliable" }).value :: index<types.Event, "type">

	return {
		id = stat.id :: DeclId,
		kind = "event",
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),

		name = name,
		from = from,
		type = reliability,
		call = call,
	}
end

local function stat_function(ctx: Context, stat: ast.StatFunction): types.Function
	return {
		id = stat.id :: DeclId,
		kind = "function",
		scope_id = ctx.scope_id,
		attributes = attributes.from_nodes(stat.attributes),
		name = stat.name.value,
	}
end

local function stat_option(ctx: Context, stat: ast.StatOption)
	local name = stat.name.value
	local options_declarations = ctx.options_declarations
	local existing_declaration = options_declarations[name]
	if existing_declaration then
		report.duplicate_option(stat, existing_declaration)
	end

	local option_config = (options :: { [string]: options.Option })[name]
	if option_config == nil then
		report.unknown_option(stat)
	end

	local value_expr = stat.value
	if value_expr.kind ~= option_config.kind then
		report.invalid_option_type(stat, option_config.kind)
	end

	local value = value_expr.value
	if option_config.values and table.find(option_config.values, value) == nil then
		report.invalid_option_value(stat, option_config.values)
	end

	local file_options = ctx.options :: { [string]: any }
	file_options[name] = value
	options_declarations[name] = stat
end

local function traverse_block(ctx: Context, block: ast.Block, prev_collection: Collection?): Collection
	local hir = ctx.hir
	local collection: Collection = prev_collection or {
		types = {},
		events = {},
		functs = {},
	}

	for _, stat in block.statements do
		local node_id = store_node(hir, stat)
		local decl_id = node_id :: DeclId

		if stat.kind == "type" then
			local decl = stat_type(ctx, stat)
			hir.types[decl_id] = decl
			table.insert(collection.types, decl)
		elseif stat.kind == "event" then
			local decl = stat_event(ctx, stat)
			hir.events[decl_id] = decl
			table.insert(collection.events, decl)
		elseif stat.kind == "function" then
			local decl = stat_function(ctx, stat)
			hir.functs[decl_id] = decl
			table.insert(collection.functs, decl)
		elseif stat.kind == "scope" then
			local body = stat.body
			local name = stat.name.value
			local scope_id = stat.id :: ScopeId

			local parent_id = ctx.scope_id
			local parent_symbols = ctx.symbols

			local scope_symbols = symbols.child(ctx.symbols, name)
			if scope_symbols == nil then
				return panic("expected parent scope to have child scopes symbols")
			end

			ctx.scope_id = scope_id
			ctx.symbols = scope_symbols
			hir.scopes[scope_id] = {
				kind = "scope",
				id = scope_id,
				symbols = scope_symbols,
			}

			traverse_block(ctx, body, collection)

			ctx.scope_id = parent_id
			ctx.symbols = parent_symbols
		elseif stat.kind == "option" then
			stat_option(ctx, stat)
		end
	end

	return collection
end

local function traverse_ast(hir: Hir, file_id: number, ast: Ast): Collection
	local scope_id = ast.body.id :: ScopeId
	local root_symbols = ast.symbols

	local context: Context = {
		hir = hir,

		options = {},
		options_declarations = {},

		symbols = root_symbols,
		scope_id = scope_id,
	}

	hir.scopes[scope_id] = {
		kind = "scope",
		id = scope_id,
		symbols = root_symbols,
	}
	hir.options[file_id] = context.options

	return traverse_block(context, ast.body)
end

return traverse_ast
