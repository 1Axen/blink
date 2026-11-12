--!strict
--!native
--!optimize 2

local build_decls_and_tys = require("@self/build_decls_and_tys")
const build_scope_tree = require("@self/build_scope_tree")
const collect_options = require("@self/collect_options")
local compilation = require("@config/compilation")
local populate_imports = require("@self/populate_imports")
local types = require("@hir/types")

type Hir = types.Hir
type Scope = types.Scope

--- Constructs a HIR from the provided files.
local function from_files(files: compilation.Files, profile: compilation.Profile): Hir
	local file_scope_map: { [number]: Scope } = {}
	const file_options_map = collect_options(files, profile)
	for _, file_id in files.sorted_ids do
		local file_ast = files.ast_map[file_id]
		local file_tree = build_scope_tree(file_ast, profile)
		file_scope_map[file_id] = file_tree
	end

	populate_imports(files, file_scope_map, profile)

	local root_file = files.sorted_ids[#files.sorted_ids]
	local root_scope = file_scope_map[root_file]
	const decls, tys = build_decls_and_tys(root_scope)

	return {
		tys = tys,
		types = decls.types,
		events = decls.events,
		functs = decls.functs,
		scopes = decls.scopes,
		options = file_options_map,
		entry_scope = root_scope,
	}
end

return table.freeze({
	from_files = from_files,
})
