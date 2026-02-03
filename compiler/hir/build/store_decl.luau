local ast = require("@ast")
local types = require("@hir/types")

type Decl = types.Decl
type Scope = types.Scope
type Decls = types.Decls

local function store_decl(scope: Scope, decls: Decls, decl: Decl, identifier: ast.Identifier)
	local name = decl.name
	scope.values[name] = decl
	scope.symbols[name] = identifier

	if decl.kind == "type" then
		decls.types[decl.id] = decl
	elseif decl.kind == "event" then
		decls.events[decl.id] = decl
	elseif decl.kind == "function" then
		decls.functs[decl.id] = decl
	elseif decl.kind == "scope" then
		decls.scopes[decl.id] = decl
	end
end

return store_decl
