local ast = require("@ast")
local canonicalize_attributes = require("./canonicalize_attributes")
local compilation = require("@config/compilation")
local report = require("@compiler/report")
local search_path = require("./search_path")
local typeforge = require("@util/typeforge")
local types = require("@hir/types")
const assert_panic = require("@util/assert_panic")
const insert_into_scope = require("./insert_into_scope")

type Decl = types.Decl
type Scope = types.Scope
type DeclId = types.DeclId
type ScopeId = types.ScopeId

type Files = compilation.Files
type FileScopeMap = { [number]: Scope }

type Extra = index<ast.StatImport, "extra">

const function star_import(into_scope: Scope, from_scope: Scope, extra: typeforge.Pick<Extra, "all">)
	const as_symbol = extra.into_scope
	-- from "<path>" import *
	if as_symbol == nil then
		const symbols = from_scope.symbols
		for name, decl in from_scope.values do
			const symbol = assert_panic(symbols[name], "scope value should have a corresponding symbol")
			const _, previous = search_path(into_scope, { name })
			if previous then
				report.shadow(name, extra.star, previous)
			end

			insert_into_scope(into_scope, symbol, decl)
		end
	-- from "<path>" import * as <name>
	else
		const name = as_symbol.value
		const _, previous = search_path(into_scope, { name })
		if previous then
			report.shadow(name, as_symbol, previous)
		end

		const new_scope: Scope = {
			id = from_scope.id,
			kind = "scope",
			name = name,
			node = from_scope.node,
			parent = into_scope,
			attributes = {},
			values = from_scope.values,
			symbols = from_scope.symbols,
		}

		insert_into_scope(into_scope, as_symbol, new_scope)
	end
end

const function destructured_import(
	into_scope: Scope,
	from_scope: Scope,
	values: index<typeforge.Pick<Extra, "destructured">, "values">
)
	for _, value in values do
		local path = value.path
		local segments = table.create<<string>>(#path.segments)
		for index, segment in path.segments do
			segments[index] = segment.value
		end

		local decl = search_path(from_scope, segments)
		if decl == nil then
			report.unknown_reference(path)
		end

		assert(decl, "unreachable")

		local name = decl.name
		local rename_to = value.rename_to
		local identifier = rename_to or path.segments[#path.segments]

		if rename_to then
			local mutable_decl: typeforge.Writeable<Decl> = table.clone(decl) :: any
			mutable_decl.name = rename_to.value
			name = mutable_decl.name
			decl = (mutable_decl :: any) :: Decl
		end

		local _, previous = search_path(into_scope, { name })
		if previous ~= nil then
			report.shadow(name, identifier, previous)
		end

		insert_into_scope(into_scope, identifier, decl)
	end
end

local function perform_import(into_scope: Scope, from_scope: Scope, import_stat: ast.StatImport)
	local extra = import_stat.extra
	if extra.kind == "all" then
		star_import(into_scope, from_scope, extra)
	elseif extra.kind == "destructured" then
		destructured_import(into_scope, from_scope, extra.values)
	end
end

local function populate_imports(files: Files, file_scope_map: FileScopeMap, profile: compilation.Profile)
	local ast_map = files.ast_map
	local imports_map = files.imports_map

	for _, file_id in files.sorted_ids do
		local file_ast = ast_map[file_id]
		local file_scope = file_scope_map[file_id]

		local queue: { { scope: Scope, statements: { ast.Statement } } } = {}
		table.insert(queue, {
			scope = file_scope,
			statements = file_ast.body.statements,
		})

		while true do
			local entry = table.remove(queue)
			if entry == nil then
				break
			end

			local into_scope = entry.scope
			for _, value in into_scope.values do
				if value.kind ~= "scope" then
					continue
				end

				const node = value.node
				if node.kind ~= "scope" then
					continue
				end

				table.insert(queue, {
					scope = value,
					statements = node.body.statements,
				})
			end

			for _, stat in entry.statements do
				if stat.kind ~= "import" then
					continue
				end

				const attributes = canonicalize_attributes(stat.attributes)
				if attributes.profile and attributes.profile ~= profile then
					continue
				end

				local import_file_id = imports_map[stat]
				local from_scope = file_scope_map[import_file_id]
				perform_import(into_scope, from_scope, stat)
			end
		end
	end
end

return populate_imports
