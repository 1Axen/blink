local ast = require("@ast")
local compilation = require("@config/compilation")
local report = require("@compiler/report")
local search_path = require("./search_path")
local store_decl = require("./store_decl")
local typeforge = require("@util/typeforge")
local types = require("@hir/types")

type Decl = types.Decl
type Scope = types.Scope
type Decls = types.Decls
type ScopeId = types.ScopeId

type Files = compilation.Files
type FileDeclsMap = { [number]: Decls }

local function parse_import(
	scope: Scope,
	decls: Decls,
	import_scope: Scope,
	import_decls: Decls,
	import_stat: ast.StatImport
)
	local extra = import_stat.extra
	if extra.kind == "all" then
		local into_scope = extra.into_scope
		if into_scope then
			local name = into_scope.value
			local _, previous = search_path(scope, { name })
			if previous then
				report.shadow(name, into_scope, previous)
			end

			local new_scope: Scope = {
				id = import_scope.id,
				kind = "scope",
				name = name,
				node = import_scope.node,
				scope = scope,
				attributes = {},
				values = import_scope.values,
				symbols = import_scope.symbols,
			}

			store_decl(scope, decls, new_scope, into_scope)
		else
			for _, decl_map in { import_decls.types, import_decls.events, import_decls.functs } do
				for _, decl in decl_map do
					local name = decl.name
					local _, previous = search_path(scope, name)
					if previous then
						report.shadow(name, extra.star, previous)
					end

					store_decl(scope, decls, decl, extra.star)
				end
			end

			for scope_id, child_scope in import_decls.scopes do
				-- skip the root scope
				if child_scope.scope == nil then
					continue
				end

				local name = child_scope.name
				local _, previous = search_path(scope, { name })
				if previous then
					report.shadow(name, extra.star, previous)
				end

				store_decl(scope, decls, child_scope, extra.star)
			end
		end
	elseif extra.kind == "destructured" then
		for _, value in extra.values do
			local path = value.path
			local segments = table.create(#path.segments) :: { string }
			for index, segment in path.segments do
				segments[index] = segment.value
			end

			local decl = search_path(import_scope, segments)
			if decl == nil then
				report.unknown_reference(path)
			end

			assert(decl)

			local name = decl.name
			local rename_to = value.rename_to
			local identifier = rename_to or path.segments[#path.segments]

			if rename_to then
				local mutable_decl: typeforge.Writeable<Decl> = table.clone(decl) :: any
				mutable_decl.name = rename_to.value
				name = mutable_decl.name
				decl = (mutable_decl :: any) :: Decl
			end

			local _, previous = search_path(scope, { name })
			if previous ~= nil then
				report.shadow(name, identifier, previous)
			end

			store_decl(scope, decls, decl, identifier)
		end
	end
end

local function populate_imports(files: Files, decls_map: FileDeclsMap)
	local ast_map = files.ast_map
	local imports_map = files.imports_map

	for _, file_id in files.sorted_ids do
		local file_ast = ast_map[file_id]
		local file_decls = decls_map[file_id]

		local scopes: { { decl: Scope, statements: { ast.Statement } } } = {}
		table.insert(scopes, {
			decl = file_decls.scopes[file_ast.body.id :: ScopeId],
			statements = file_ast.body.statements,
		})

		while true do
			local scope = table.remove(scopes)
			if scope == nil then
				break
			end

			local source_scope = scope.decl
			for _, stat in scope.statements do
				if stat.kind == "scope" then
					table.insert(scopes, {
						decl = file_decls.scopes[stat.id :: ScopeId],
						statements = stat.body.statements,
					})
				elseif stat.kind == "import" then
					local import_file_id = imports_map[stat]

					local import_ast = ast_map[import_file_id]
					local import_decls = decls_map[import_file_id]
					local import_scope = import_decls.scopes[import_ast.body.id :: ScopeId]

					parse_import(source_scope, file_decls, import_scope, import_decls, stat)
				end
			end
		end
	end
end

return populate_imports
