--!strict

local ast = require("@ast")
local attributes = require("@config/attributes")
local options = require("@config/options")
local ty = require("@ty/types")

type Ty = ty.Ty
type Node = ast.Node

type TyId<T = Ty> = ty.TyId<T>
type NodeId = ast.NodeId

export type Parameter = {
	name: string?,
	ty_id: TyId,
}

export type Type = {
	read id: DeclId,
	read kind: "type",
	read name: string,
	read scope_id: ScopeId,
	read attributes: attributes.Attributes,

	read ty_id: TyId,
	read generics: { ty.Generic }?,
}

export type Event = {
	read id: DeclId,
	read kind: "event",
	read name: string,
	read scope_id: ScopeId,
	read attributes: attributes.Attributes,

	read from: "Server" | "Client" | "Both",
	read type: "Reliable" | "Unreliable",
	read call: "ManySync" | "SingleSync" | "ManyAsync" | "SingleAsync" | "Polling",
	data: { Parameter }?,
}

export type Function = {
	read id: DeclId,
	read kind: "function",
	read name: string,
	read scope_id: ScopeId,
	read attributes: attributes.Attributes,

	read yield: "Coroutine" | "Promise" | "Future",
	data: { Parameter }?,
	ret: { Parameter }?,
}

--stylua: ignore
export type Decl = 
    | Type
    | Event
    | Function

export type DeclId = { write __kind: "decl" }
export type ScopeId = { write __kind: "scope" }

export type Scope = ast.Symbols

export type Hir = {
	read tys: { [TyId]: Ty },
	read nodes: { [NodeId]: Node },

	read types: { [DeclId]: Type },
	read events: { [DeclId]: Event },
	read functs: { [DeclId]: Function },
	read scopes: { [ScopeId]: Scope },

	--- [file_id]: FileOptions
	read options: { [number]: options.FileOptions? },
}

return nil
