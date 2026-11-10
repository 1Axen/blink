const ast = require("@ast")
const report = require("@compiler/report")
const compilation = require("@config/compilation")
const types = require("@hir/types")
const insert_into_scope = require("./insert_into_scope")
const search_path = require("./search_path")
const canonicalize_attributes = require("./canonicalize_attributes")
const ty = require("@ty")
const typeforge = require("@util/typeforge")

type TyId = ty.TyId
type DeclId = types.DeclId
type ScopeId = types.ScopeId

type Decl = types.Decl
type Scope = types.Scope

type Profile = compilation.Profile

type Context = {
	scope: Scope,
	read profile: Profile,
}

const function assert_identifier_one_of(ident: ast.Identifier, valid: { string }): ast.Identifier
	local value = ident.value
	if table.find(valid, value) == nil then
		return report.expect_node_one_of(ident, valid, value)
	end

	return ident
end

const function type_decl(stat: ast.StatType): types.Type
	local generics: { ty.Generic }?
	if stat.generics then
		generics = {}
		for index, node in stat.generics.values do
			const name = node.name.value
			const generic_ty = ty.generic(node :: any, name, index)
			generics[index] = generic_ty
		end
	end

	return {
		id = stat.id :: DeclId,
		kind = "type",
		name = stat.name.value,
		node = stat,
		attributes = canonicalize_attributes(stat.attributes),

		ty_id = stat.id :: TyId,
		generics = generics,
	}
end

const function event_decl(stat: ast.StatEvent): types.Event
	const name = stat.name.value
	const from = assert_identifier_one_of(stat.from, { "Client", "Server", "Both" }).value :: index<types.Event, "from">
	const call = assert_identifier_one_of(
		stat.call,
		{ "ManySync", "SingleSync", "ManyAsync", "SingleAsync", "Polling" }
	).value :: index<types.Event, "call">
	const reliability =
		assert_identifier_one_of(stat.type, { "Reliable", "Unreliable" }).value :: index<types.Event, "type">

	return {
		id = stat.id :: DeclId,
		kind = "event",
		name = name,
		node = stat,
		attributes = canonicalize_attributes(stat.attributes),

		from = from,
		type = reliability,
		call = call,
	}
end

const function funct_decl(stat: ast.StatFunction): types.Function
	return {
		id = stat.id :: DeclId,
		kind = "function",
		name = stat.name.value,
		node = stat,
		attributes = canonicalize_attributes(stat.attributes),
	}
end

const function scope_decl(ctx: Context, stat: ast.StatScope): types.Scope
	return {
		id = stat.id :: ScopeId,
		kind = "scope",
		node = stat,
		name = stat.name.value,
		parent = ctx.scope,
		attributes = canonicalize_attributes(stat.attributes),

		values = {},
		symbols = {},
	}
end

const function traverse_block(ctx: Context, block: ast.Block)
	const scope = ctx.scope
	for _, statement in block.statements do
		--stylua: ignore
		local decl: Decl? = if statement.kind == "type" then 
				type_decl(statement)
			elseif statement.kind == "event" then 
				event_decl(statement)
			elseif statement.kind == "function" then 
				funct_decl(statement)
			elseif statement.kind == "scope" then 
				scope_decl(ctx, statement)
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
			const name = decl.name
			const node: typeforge.Drop<index<Decl, "node">, ast.StatImport> = decl.node :: any
			const symbol = node.name
			const _, previous = search_path(scope, { name })
			if previous then
				report.shadow(name, symbol, previous)
			end

			insert_into_scope(scope, symbol, decl)
		end

		if decl.kind == "scope" and statement.kind == "scope" then
			ctx.scope = decl
			traverse_block(ctx, statement.body)
		end
	end
end

const function build_scope_tree(ast: ast.Ast, profile: Profile): Scope
	const root_id = ast.body.id :: ScopeId
	const root_scope: Scope = {
		kind = "scope",
		id = root_id,
		name = "",
		node = ast :: any,
		parent = nil,
		values = {},
		symbols = {},
		attributes = {},
	}

	const context: Context = {
		scope = root_scope,
		profile = profile,
	}

	traverse_block(context, ast.body)
	return root_scope
end

return build_scope_tree
