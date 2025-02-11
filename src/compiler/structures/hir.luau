--!strict

local ty = require("@structures/ty")
local ast = require("@structures/ast")

local options = require("@config/options")
local attributes = require("@config/attributes")

local panic = require("@util/panic")

type Ty = ty.Ty
type Node = ast.Node

type TyId<T = Ty> = ty.TyId<T>
type NodeId<T = Node> = ast.NodeId<T>

export type Parameter = {
    name: string?,
    value: TyId
}

export type Type<T = ty.Ty> = {
    read kind: "type",
    read name: string,
    read scope: ScopeId,
    read attributes: attributes.TypeAttributes,

    read ty: TyId<T>,
    read generics: {TyId<ty.Generic>}?
} 

export type Event = {
    read kind: "event",
    read name: string,
    read scope: ScopeId,
    read attributes: attributes.SharedAttributes,

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
    read attributes: attributes.SharedAttributes,

    read yield: "Coroutine" | "Promise" | "Future",
    read data: {Parameter}?,
    read ret: {Parameter}?
}

export type Decl = 
    | Type
    | Event
    | Function
;

export type DeclId<T = Decl> = number & { __kind: "decl", __T: T}
export type ScopeId = number & { __kind: "scope" }

export type Hir = {
    read tys: {[TyId]: Ty},
    read decls: {[DeclId]: Decl},
    read nodes: {[NodeId]: Node},
    read scopes: {[ScopeId]: string},
    --- [file_id]: FileOptions
    read options: {[number]: options.FileOptions}
}

local function ty_from_id<T>(hir: Hir, ty_id: TyId<T>): T
    local ty = hir.tys[ty_id]
    if ty == nil then
        return panic("Expected ty_id to point to a ty")
    end

    return ty
end

local function decl_from_id<T>(hir: Hir, decl_id: DeclId<T>): T
    local decl = hir.decls[decl_id]
    if decl == nil then
        return panic("Expected decl_id to point to a decl")
    end

    return decl
end

local function node_from_id<T>(hir: Hir, node_id: NodeId<T>): T
    local node = hir.nodes[node_id]
    if node == nil then
        return panic("Expected node_id to point to a node")
    end

    return node
end

return table.freeze({
    ty_from_id = ty_from_id,
    decl_from_id = decl_from_id,
    node_from_id = node_from_id,
})