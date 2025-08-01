--!strict

local ast = require("@ast/types")
local ty = require("@ty/types")

local attributes = require("@config/attributes")
local options = require("@config/options")

local panic = require("@util/panic")

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
	read generics: { TyId<ty.Generic> }?,
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
	read options: { [number]: options.FileOptions },
}

local function ty_from_id<T>(hir: Hir, ty_id: TyId<T>): T
	local ty = hir.tys[ty_id]
	if ty == nil then
		return panic("Expected ty_id to point to a ty")
	end

	return ty
end

local function type_from_id(hir: Hir, decl_id: DeclId): Type
	local decl = hir.types[decl_id]
	if decl == nil then
		return panic("Expected decl_id to point to a decl")
	end

	return decl
end

local function node_from_id(hir: Hir, node_id: NodeId): Node
	local node = hir.nodes[node_id]
	if node == nil then
		return panic("Expected node_id to point to a node")
	end

	return node
end

local function scope_from_id(hir: Hir, scope_id: ScopeId): Scope
	local scope = hir.scopes[scope_id]
	if scope == nil then
		return panic("Expected scope_id to point to a scope")
	end

	return scope
end

local function follow(hir: Hir, ty: ty.Ty): ty.Ty
	if ty.kind == "optional" then
		local of = ty_from_id(hir, ty.of)
		return follow(hir, of)
	elseif ty.kind == "generic_type" then
		local body = ty_from_id(hir, ty.body)
		return follow(hir, body)
	end

	-- SOLVER BUG
	return ty :: any
end

return table.freeze({
	follow = follow,

	ty_from_id = ty_from_id,
	decl_from_id = type_from_id,
	node_from_id = node_from_id,
	scope_from_id = scope_from_id,
})
