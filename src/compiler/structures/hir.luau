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
    read generics: {TyId<ty.Generic>}?
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

return table.freeze({})