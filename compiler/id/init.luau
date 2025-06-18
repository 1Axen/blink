local ast = require("@ast/types")
local hir = require("@hir/types")
local lir = require("@lir/types")
local panic = require("@util/panic")
local ty = require("@ty/types")

type Ty = ty.Ty
type Decl = hir.Decl
type Node = ast.Node

type SetId = lir.SetId
type TyId<T = Ty> = ty.TyId<>
type DeclId<T = Decl> = hir.DeclId<T>
type NodeId<T = Node> = ast.NodeId<T>
type ScopeId = hir.ScopeId

type u32 = number

--[=[
Ids are u32s, their format is as follows:
* TYPE  FILE     INDEX
* 0-8   0-128    0-4,194,303
* 3 bits 7 bits  22 bits

Type flags:
* 0b000 - Node
* 0b001 - Scope
* 0b010 - Def
* 0b011 - Ty
* 0b100 - Set
]=]
--stylua: ignore
export type Id = 
    | TyId
	| SetId
    | DeclId
    | NodeId
    | ScopeId

--stylua: ignore
export type IdKind = 
	| "Ty" 
	| "Set"
	| "Decl" 
	| "Node" 
	| "Scope"

local TY_FLAG = 0b011
local SET_FLAG = 0b100
local DECL_FLAG = 0b010
local NODE_FLAG = 0b000
local SCOPE_FLAG = 0b001

local TYPE_MASK = 2 ^ 3
local INDEX_MASK = 2 ^ 10

local function id_type(id: Id)
	local id_u32 = (id :: any) :: u32
	return id_u32 % TYPE_MASK
end

local function id_kind(id: Id): IdKind
	local flag = id_type(id)
	if flag == TY_FLAG then
		return "Ty"
	elseif flag == SET_FLAG then
		return "Set"
	elseif flag == DECL_FLAG then
		return "Decl"
	elseif flag == SCOPE_FLAG then
		return "Scope"
	elseif flag == NODE_FLAG then
		return "Node"
	end

	return panic(`unhandled type flag: {flag}`)
end

local function id_file(id: Id)
	local id_u32 = (id :: any) :: u32
	return (id_u32 % INDEX_MASK) // TYPE_MASK
end

local function id_index(id: Id)
	local id_u32 = (id :: any) :: u32
	return id_u32 // INDEX_MASK
end

local function id_set_type(id: Id, flag: number)
	local id_u32 = (id :: any) :: u32
	return flag + ((id_u32 // TYPE_MASK) * 2 ^ 3)
end

local function to_ty_id(id: Id): TyId
	return id_set_type(id, TY_FLAG) :: any
end

local function to_set_id(id: Id): SetId
	return id_set_type(id, SET_FLAG) :: any
end

local function to_decl_id(id: Id): DeclId
	return id_set_type(id, DECL_FLAG) :: any
end

local function to_node_id(id: Id): NodeId
	return id_set_type(id, NODE_FLAG) :: any
end

local function to_scope_id(id: Id): ScopeId
	return id_set_type(id, SCOPE_FLAG) :: any
end

local function create_node_id(file: number, index: number): NodeId
	return (file * TYPE_MASK) + (index * INDEX_MASK) :: any
end

return table.freeze({
	type = id_type,
	kind = id_kind,
	file = id_file,
	index = id_index,

	to_ty_id = to_ty_id,
	to_set_id = to_set_id,
	to_decl_id = to_decl_id,
	to_node_id = to_node_id,
	to_scope_id = to_scope_id,

	ty_id = table.freeze({
		to_node_id = to_node_id :: <T>(TyId<T>) -> NodeId,
	}),
	decl_id = table.freeze({
		to_node_id = to_node_id :: <T>(DeclId<T>) -> NodeId,
	}),
	scope_id = table.freeze({
		to_node_id = to_node_id :: (ScopeId) -> NodeId,
	}),
	node_id = table.freeze({
		create = create_node_id,
		to_ty_id = to_ty_id :: <T>(NodeId<T>) -> TyId,
		to_decl_id = to_decl_id :: <T>(NodeId<T>) -> DeclId,
		to_scope_id = to_scope_id :: <T>(NodeId<T>) -> ScopeId,
	}),

	TY_FLAG = TY_FLAG,
	SET_FLAG = SET_FLAG,
	DECL_FLAG = DECL_FLAG,
	NODE_FLAG = NODE_FLAG,
	SCOPE_FLAG = SCOPE_FLAG,

	DUMMY_ID = create_node_id(2 ^ 8 - 1, 2 ^ 22 - 1),
})
