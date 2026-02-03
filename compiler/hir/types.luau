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
	read node: ast.StatType,
	read scope: Scope,
	read attributes: attributes.Attributes,

	read ty_id: TyId,
	read generics: { ty.Generic }?,
}

export type Event = {
	read id: DeclId,
	read kind: "event",
	read name: string,
	read node: ast.StatEvent,
	read scope: Scope,
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
	read node: ast.StatFunction,
	read scope: Scope,
	read attributes: attributes.Attributes,

	data: { Parameter }?,
	ret: { Parameter }?,
}

export type Scope = {
	read id: ScopeId,
	read kind: "scope",
	read name: string,
	read node: ast.StatScope | ast.StatImport,
	read scope: Scope?,
	read attributes: attributes.Attributes,

	read values: { [string]: Decl },
	read symbols: { [string]: ast.Identifier },
}

--stylua: ignore
export type Decl = 
    | Type
    | Event
	| Scope
    | Function

export type DeclId = { write __kind: "decl" }
export type ScopeId = { write __kind: "scope" }

export type Hir = {
	read tys: { [TyId]: Ty },
	read types: { [DeclId]: Type },
	read events: { [DeclId]: Event },
	read functs: { [DeclId]: Function },
	read scopes: { [ScopeId]: Scope },
	--- [file_id]: FileOptions
	read options: { [number]: options.FileOptions? },
	read entry_scope: Scope,
}

export type Decls = {
	read types: { [DeclId]: Type },
	read events: { [DeclId]: Event },
	read functs: { [DeclId]: Function },
	read scopes: { [ScopeId]: Scope },
}

return nil
