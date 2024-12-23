--!strict

local ty = require("@compiler/structures/ty")
local ast = require("@compiler/structures/ast")

local panic = require("@util/panic")

type Ty = ty.Ty
type Node = ast.Node

type TyId<T = Ty> = ty.TyId<T>
type NodeId<T = Node> = ast.NodeId<T>
export type DeclId<T = Decl> = number & { __kind: "decl", __T: T}
export type ScopeId = number & { __kind: "scope" }

export type Parameter = {
    name: string?,
    value: TyId
}

export type Type<T = ty.Ty> = {
    read kind: "type",
    read name: string,
    read scope: ScopeId,

    read ty: TyId<T>,
    read generics: {TyId<ty.Placeholder>}?
} 

export type Event = {
    read kind: "event",
    read name: string,
    read scope: ScopeId,

    read from: "Server" | "Client" | "Both",
    read type: "Reliable" | "Unreliable",
    read call: "ManySync" | "SingleSync" | "ManyAsync" | "SingleAsync",
    read poll: boolean,
    read data: {Parameter}?
}

export type Function = {
    read kind: "function",
    read name: string,
    read scope: ScopeId,

    read yield: "Coroutine" | "Promise" | "Future",
    read data: {Parameter}?,
    read ret: {Parameter}?
}

export type Decl = 
    | Type
    | Event
    | Function
;

export type Hir = {
    read tys: {[TyId]: Ty},
    read decls: {[DeclId]: Decl},
    read nodes: {[NodeId]: Node},
    read scopes: {[ScopeId]: string},
}

local function ty_from_id(hir: Hir, ty_id: TyId): Ty
    local ty = hir.tys[ty_id]
    if ty == nil then
        return panic("Expected ty_id to point to a ty")
    end

    return ty
end

local function node_from_id(hir: Hir, node_id: NodeId): Node
    local node = hir.nodes[node_id]
    if node == nil then
        return panic("Expected node_id to point to a node")
    end

    return node
end

return table.freeze({})