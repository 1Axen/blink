--!strict
--!native
--!optimize 2

local ast = require("@ast")
local build = require("@self/build")
local dereferencing = require("@hir/analysis/dereferencing")
local flattening = require("@hir/analysis/flattening")
local format = require("@self/format")
local instantiation = require("@hir/analysis/instantiation")
local lookup = require("@self/lookup")
local type_checking = require("@hir/analysis/type_checking")
local types = require("@self/types")

export type Parameter = types.Parameter
export type Type = types.Type
export type Event = types.Event
export type Function = types.Function
export type Decl = types.Decl
export type Scope = ast.Symbols
export type DeclId = types.DeclId
export type ScopeId = types.ScopeId
export type Hir = types.Hir

local function hir_from_files(files: { [number]: ast.Ast }): Hir
	local hir = build.from_files(files)
	instantiation.instantiate(hir)
	dereferencing.dereference(hir)
	flattening.flatten(hir)
	type_checking.type_check(hir)
	return hir
end

return table.freeze({
	format = format,
	from_files = hir_from_files,

	follow = lookup.follow,
	ty_from_id = lookup.ty_from_id,
	decl_from_id = lookup.decl_from_id,
	node_from_id = lookup.node_from_id,
	scope_from_id = lookup.scope_from_id,
})
