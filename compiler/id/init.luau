local ast = require("@ast/types")
local hir = require("@hir/types")
local lir = require("@lir/types")
local ty = require("@ty/types")

type Ty = ty.Ty
type Decl = hir.Decl
type Node = ast.Node

type SetId = lir.FnId
type TyId<T = Ty> = ty.TyId<>
type DeclId = hir.DeclId
type NodeId = ast.NodeId
type ScopeId = hir.ScopeId

type u32 = number

--[=[
|FIELD|WIDTH|
|-----|-----|
|File|`8 bits`|
|Index|`24 bits`|
]=]
--stylua: ignore
export type Id = 
    | TyId
	| SetId
    | DeclId
    | NodeId
	| ScopeId

local INDEX_MASK = 2 ^ 8

local function id_file(id: Id)
	return (id :: u32) % INDEX_MASK
end

local function id_index(id: Id)
	return (id :: u32) // INDEX_MASK
end

local function create(file: number, index: number): Id
	return file + (index * INDEX_MASK)
end

return table.freeze({
	file = id_file,
	index = id_index,
	create = create,
	DUMMY_ID = create(2 ^ 8 - 1, 2 ^ 22 - 1),
})
