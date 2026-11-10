const types = require("@hir/types")

type Decl = types.Decl
type DeclId = types.DeclId

type Scope = types.Scope
type Decls = types.Decls

const function collect_decls(root_scope: Scope): Decls
	const decls: Decls = {
		types = {},
		scopes = {},
		events = {},
		functs = {},
	}

	const seen: { [Decl]: true? } = {}
	const queue = table.create<<Scope>>(4)
	table.insert(queue, root_scope)

	while true do
		const scope = table.remove(queue)
		if scope == nil then
			break
		end

		for _, decl in scope.values do
			if seen[decl] then
				continue
			end

			seen[decl] = true
			if decl.kind == "type" then
				decls.types[decl.id] = decl
			elseif decl.kind == "event" then
				decls.events[decl.id] = decl
			elseif decl.kind == "function" then
				decls.functs[decl.id] = decl
			elseif decl.kind == "scope" then
				table.insert(queue, decl)
				decls.scopes[decl.id] = decl
			end
		end
	end

	return decls
end

return collect_decls
