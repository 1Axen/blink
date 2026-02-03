local ast = require("@ast")
local types = require("@hir/types")

type Decl = types.Decl
type Scope = types.Scope
type Identifier = ast.Identifier

local function search_path(from: Scope, path: { string }): (Decl?, Identifier?)
	local index = 1
	local length = #path
	local segments = path :: { string? }

	local scope: Scope? = from
	while scope do
		local segment = segments[index]
		if segment == nil then
			break
		end

		local value = scope.values[segment]
		-- search the parent scope
		if value == nil then
			scope = scope.scope
			continue
		-- search the found scope
		elseif value.kind == "scope" and index ~= length then
			index += 1
			scope = value
			continue
		end

		return value, scope.symbols[segment]
	end

	return nil, nil
end

return search_path
