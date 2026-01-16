local ast = require("@ast")
local id = require("@compiler/id")
local panic = require("@util/panic")
local types = require("@hir/types")

type Hir = types.Hir
type Node = ast.Node
type NodeId = ast.NodeId

local function store_node(hir: Hir, node: Node): NodeId
	local node_id = node.id
	if node_id == id.DUMMY_ID then
		panic(`AST node [{ast.format.node(node)}] wasn't assigned an id`)
	end

	hir.nodes[node_id] = node
	return node_id
end

return store_node
