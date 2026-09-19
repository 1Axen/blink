local ast = require("@ast")
local canonicalize_attributes = require("./canonicalize_attributes")
local compilation = require("@config/compilation")
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

type Context = {
	read decls: Decls,
	read profile: compilation.Profile,
}

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
		attributes = canonicalize_attributes(stat.attributes),

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
		name = name,
		node = stat,
		scope = scope,
		attributes = canonicalize_attributes(stat.attributes),

		from = from,
		type = reliability,
		call = call,
	}
end

local function decl_funct(scope: Scope, stat: ast.StatFunction): types.Function
	return {
		id = stat.id :: DeclId,
		kind = "function",
		name = stat.name.value,
		node = stat,
		scope = scope,
		attributes = canonicalize_attributes(stat.attributes),
	}
end

local function decl_scope(scope: Scope, stat: ast.StatScope): types.Scope
	return {
		id = stat.body.id :: ScopeId,
		kind = "scope",
		node = stat,
		name = stat.name.value,
		scope = scope,
		attributes = canonicalize_attributes(stat.attributes),

		values = {},
		symbols = {},
	}
end

local function traverse_block(ctx: Context, scope: Scope, block: ast.Block)
	const decls = ctx.decls
	for _, stat in block.statements do
		--stylua: ignore
		local decl: Decl? = if stat.kind == "type" then 
				decl_type(scope, stat)
			elseif stat.kind == "event" then 
				decl_event(scope, stat)
			elseif stat.kind == "function" then 
				decl_funct(scope, stat)
			elseif stat.kind == "scope" then 
				decl_scope(scope, stat)
			else 
				nil

		if decl == nil then
			continue
		end

		const attributes = decl.attributes
		if attributes.profile and attributes.profile ~= ctx.profile then
			continue
		end

		do
			local name = decl.name
			local node = decl.node :: typeforge.Drop<index<Decl, "node">, ast.StatImport>
			local _, previous = search_path(scope, { name })
			if previous then
				report.shadow(name, node.name, previous)
			end

			store_decl(scope, decls, decl, node.name)
		end

		if decl.kind == "scope" then
			local node = decl.node :: ast.StatScope
			traverse_block(ctx, decl, node.body)
		end
	end
end

local function collect_decls(ast: Ast, profile: compilation.Profile): Decls
	local scope_id = ast.body.id :: ScopeId
	local scope: Scope = {
		kind = "scope",
		id = scope_id,
		name = "",
		node = ast :: any,
		scope = nil,
		values = {},
		symbols = {},
		attributes = {},
	}

	local decls: Decls = {
		types = {},
		events = {},
		functs = {},
		scopes = { [scope_id] = scope },
	}

	const context: Context = {
		scope = scope,
		decls = decls,
		profile = profile,
	}

	traverse_block(context, scope, ast.body)
	return decls
end

return collect_decls
