local ast = require("@ast")
local attributes = require("./attributes")
local report = require("@compiler/report")
local search_path = require("./search_path")
local store_decl = require("./store_decl")
local ty = require("@ty")
local typeforge = require("@util/typeforge")
local types = require("@hir/types")

type Ty = ty.Ty
type Decl = types.Decl
type Scope = types.Scope
type Decls = types.Decls

type Node = ast.Node
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId<T>
type DeclId = types.DeclId
type ScopeId = types.ScopeId

local function assert_identifier_one_of(ident: ast.Identifier, valid: { string }): ast.Identifier
	local value = ident.value
	if table.find(valid, value) == nil then
		return report.expect_node_one_of(ident, valid, value)
	end

	return ident
end

local function decl_type(scope: Scope, stat: ast.StatType): types.Type
	--> lower generics
	local parameters: { ty.Generic }?
	if stat.generics then
		parameters = {}

		for index, node in stat.generics.values do
			local name = node.name.value
			local generic = ty.generic(node :: any, name, index)
			parameters[index] = generic
		end
	end

	--> lower expression
	return {
		id = stat.id :: DeclId,
		kind = "type",
		name = stat.name.value,
		node = stat,
		scope = scope,
		attributes = attributes.from_nodes(stat.attributes),

		ty_id = stat.id :: TyId,
		generics = parameters,
	}
end

local function decl_event(scope: Scope, stat: ast.StatEvent): types.Event
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
		node = stat,
		scope = scope,
		attributes = attributes.from_nodes(stat.attributes),

		name = name,
		from = from,
		type = reliability,
		call = call,
	}
end

local function decl_funct(scope: Scope, stat: ast.StatFunction): types.Function
	return {
		id = stat.id :: DeclId,
		kind = "function",
		node = stat,
		scope = scope,
		attributes = attributes.from_nodes(stat.attributes),
		name = stat.name.value,
	}
end

local function decl_scope(scope: Scope, stat: ast.StatScope): types.Scope
	return {
		kind = "scope",
		id = stat.body.id :: ScopeId,
		name = stat.name.value,
		node = stat,
		scope = scope,
		attributes = {},
		values = {},
		symbols = {},
	}
end

local function traverse_block(file_decls: Decls, scope: Scope, block: ast.Block)
	for _, stat in block.statements do
		local decl: Decl?
		if stat.kind == "type" then
			decl = decl_type(scope, stat)
		elseif stat.kind == "event" then
			decl = decl_event(scope, stat)
		elseif stat.kind == "function" then
			decl = decl_funct(scope, stat)
		elseif stat.kind == "scope" then
			decl = decl_scope(scope, stat)
		end

		if decl == nil then
			continue
		end

		do
			local name = decl.name
			local node: typeforge.Drop<index<Decl, "node">, ast.StatImport> = decl.node :: any
			local _, previous = search_path(scope, { name })
			if previous then
				report.shadow(name, node.name, previous)
			end

			store_decl(scope, file_decls, decl, node.name)
		end

		if decl.kind == "scope" then
			local node = decl.node :: ast.StatScope
			traverse_block(file_decls, decl, node.body)
		end
	end
end

local function collect_decls(file_id: number, ast: Ast): Decls
	local scope_id = ast.body.id :: ScopeId
	local root_scope: Scope = {
		kind = "scope",
		id = scope_id,
		name = "",
		node = ast :: any,
		scope = nil,
		attributes = {},
		values = {},
		symbols = {},
	}

	local file_decls: Decls = {
		types = {},
		events = {},
		functs = {},
		scopes = { [scope_id] = root_scope },
	}

	traverse_block(file_decls, root_scope, ast.body)

	return file_decls
end

return collect_decls
