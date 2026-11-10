const ast = require("@ast")
const types = require("@hir/types")

const function insert_into_scope(scope: types.Scope, symbol: ast.Identifier, decl: types.Decl)
	const name = symbol.value
	scope.values[name] = decl
	scope.symbols[name] = symbol
end

return insert_into_scope
