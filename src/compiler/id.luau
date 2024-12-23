local ty = require("@compiler/types/ty")
local hir = require("@compiler/types/hir")
local ast = require("@compiler/types/ast")
local panic = require("@util/panic")("ids util")

type TyId = ty.TyId
type DeclId = hir.DeclId
type NodeId = ast.NodeId
type ScopeId = hir.ScopeId

--- Ids are 32 bit integers
--- All ids (except NodeId) originate from a `NodeId`
--- The 2 most significant bits indicate the id type:
--- * 0b00 - Node
--- * 0b01 - Scope
--- * 0b10 - Def
--- * 0b11 - Ty
--- The remaining 30 bits are used for the actual identifying portion
export type Id = 
    | TyId
    | DeclId
    | NodeId
    | ScopeId

export type IdKind = "Ty" | "Decl" | "Node" | "Scope"

local TY_FLAG = 0b11
local DECL_FLAG = 0b10
local NODE_FLAG = 0b00
local SCOPE_FLAG = 0b01

local function get_kind(id: Id): IdKind
    local flag = bit32.extract(id, 30, 2)
    if flag == TY_FLAG then
        return "Ty"
    elseif flag == DECL_FLAG then
        return "Decl"
    elseif flag == SCOPE_FLAG then
        return "Scope"
    elseif flag == NODE_FLAG then
        return "Node"
    end

    return panic(`Can't get kind of id: "{id}"`)
end

local function set_flag(id: Id, flag: number): Id
    return bit32.replace(id, flag, 30, 2)
end

local function node_id_to_ty_id(node_id: NodeId): TyId
    return set_flag(node_id, TY_FLAG) :: any
end

local function node_id_to_decl_id(node_id: NodeId): DeclId
    return set_flag(node_id, DECL_FLAG) :: any
end

local function node_id_to_scope_id(node_id: NodeId): ScopeId
    return set_flag(node_id, SCOPE_FLAG) :: any
end

local function ty_id_to_node_id(ty_id: TyId): NodeId
    return set_flag(ty_id, NODE_FLAG) :: any
end

local function decl_id_to_node_id(def_id: DeclId): NodeId
    return set_flag(def_id, NODE_FLAG) :: any
end

local function scope_id_to_node_id(scope_id: ScopeId): NodeId
    return set_flag(scope_id, NODE_FLAG) :: any
end

return table.freeze({
    kind = get_kind,

    ty_id = table.freeze({
        to_node_id = ty_id_to_node_id,
    }),
    decl_id = table.freeze({
        to_node_id = decl_id_to_node_id,
    }),
    scope_id = table.freeze({
        to_node_id = scope_id_to_node_id,
    }),
    node_id = table.freeze({
        to_ty_id = node_id_to_ty_id,
        to_decl_id = node_id_to_decl_id,
        to_scope_id = node_id_to_scope_id,
    }),

    TY_FLAG = TY_FLAG,
    DECL_FLAG = DECL_FLAG,
    NODE_FLAG = NODE_FLAG,
    SCOPE_FLAG = SCOPE_FLAG
})