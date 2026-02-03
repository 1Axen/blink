local ast = require("@ast")

local TARGETS = table.freeze({
	types = true,
	client = true,
	server = true,
})

local PROFILES = table.freeze({
	dev = true,
	test = true,
	debug = true,
	release = true,
})

export type Target = keyof<typeof(TARGETS)>
export type Profile = keyof<typeof(PROFILES)>

export type Files = {
	--- array of file ids sorted in descending order by reference count, reference count is transitive
	read sorted_ids: { number },
	--- map of file id to ast
	read ast_map: { [number]: ast.Ast },
	--- map of import node to file id
	read imports_map: { [ast.StatImport]: number },
}

return table.freeze({
	TARGETS = TARGETS,
	PROFILES = PROFILES,
})
