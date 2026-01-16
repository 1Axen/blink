local ast = require("@ast")
local types = require("@hir/types")

type Hir = types.Hir
type Node = ast.Node
type NodeId = ast.NodeId

local function store_node(hir: Hir, node: Node): NodeId
	hir.nodes[node.id] = node
	return node.id
end

return store_node
