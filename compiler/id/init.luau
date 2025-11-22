local ast_types = require("@ast/types")
local hir_types = require("@hir/types")
local lir_types = require("@lir/types")
local ty_types = require("@ty/types")

local style = require("@util/style")

type Ty = ty_types.Ty
type Decl = hir_types.Decl
type Node = ast_types.Node

type SetId = lir_types.FnId
type TyId<T = Ty> = ty_types.TyId<>
type DeclId = hir_types.DeclId
type NodeId = ast_types.NodeId
type ScopeId = hir_types.ScopeId

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
local UNIQUE_STYLE = style.combine(style.color.blue, style.modifer.dim)

local function id_file(id: Id)
	return (id :: u32) % INDEX_MASK
end

local function id_index(id: Id)
	return (id :: u32) // INDEX_MASK
end

local function create(file: number, index: number): Id
	return file + (index * INDEX_MASK)
end

local function format(any_id: Id): string
	local file = id_file(any_id)
	local index = id_index(any_id)
	return `{UNIQUE_STYLE(string.format("(%03i:%03i)", file, index))}`
end

return table.freeze({
	file = id_file,
	index = id_index,
	create = create,
	format = format,
	DUMMY_ID = create(2 ^ 8 - 1, 2 ^ 22 - 1),
})
