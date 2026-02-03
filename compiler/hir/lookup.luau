--!strict

local ast = require("@ast")
local file = require("@util/file")
local options = require("@config/options")
local ty = require("@ty/types")

local panic = require("@util/panic")
local types = require("./types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>

type Node = ast.Node
type NodeId = ast.NodeId

type Hir = types.Hir
type Decl = types.Decl
type Scope = types.Scope

type DeclId = types.DeclId
type ScopeId = types.ScopeId

local function ty_from_id<T>(hir: Hir, ty_id: TyId<T>): T
	local ty = hir.tys[ty_id]
	if ty == nil then
		return panic(`Expected TyId {ty_id} to map to a ty`)
	end

	return ty
end

local function decl_from_id(hir: Hir, decl_id: DeclId): Decl
	local decl = hir.types[decl_id]
	if decl == nil then
		return panic(`Expected DeclId {decl_id} to map to a decl`)
	end

	return decl
end

local function scope_from_id(hir: Hir, scope_id: ScopeId): Scope
	local scope = hir.scopes[scope_id]
	if scope == nil then
		return panic(`Expected ScopeId {scope_id} to map to a scope`)
	end

	return scope
end

local function file_options(hir: Hir, file: file.File): options.FileOptions
	local id = file.id
	local file_options = hir.options[id]
	if file_options == nil then
		return panic(`Expected File {file.id} to map to file options`)
	end

	return file_options
end

local function follow(hir: Hir, ty: ty.Ty): ty.Ty
	if ty.kind == "optional" then
		return follow(hir, ty.of)
	elseif ty.kind == "type_instantiation" then
		return follow(hir, ty.body)
	end

	-- SOLVER BUG
	return ty :: any
end

return table.freeze({
	follow = follow,
	file_options = file_options,

	ty_from_id = ty_from_id,
	decl_from_id = decl_from_id,
	scope_from_id = scope_from_id,
})
