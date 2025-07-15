--!strict
--!native
--!optimize 2

local constant = require("@builders/constant")
local id = require("@compiler/id")

local hir = require("@hir/types")
local lir = require("@lir/types")
local ty = require("@ty/types")

local options = require("@config/options")

local builders = require("@builders/init")
local context = require("@self/context")
local types = require("@builders/ty/types")

local panic = require("@util/panic")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

type Lir = lir.Lir
type Hir = hir.Hir

type Decl = hir.Decl
type DeclId = hir.DeclId

type Ty = ty.Ty
type TyId = ty.TyId

type Fn = lir.Fn
type FnId = lir.FnId

type Context = context.Context
type Builder = builders.Builder

local READ_PREFIX = "read_"
local WRITE_PREFIX = "write_"

local TYPE_PREFIX = "type_"
local EVENT_PREFIX = "event_"
local FUNCTION_PREFIX = "function_"

local function options_from_decl_id(ctx: Context, decl_id: DeclId): options.FileOptions
	local file_id = id.file(decl_id)
	if file_id == nil then
		return panic(`Expected declaration to be linked to a file`)
	end

	local options = ctx.hir.options[file_id]
	if options == nil then
		return panic(`Expected file to have options`)
	end

	return options
end

local function rreturns(ctx: Context, parameters: { hir.Parameter }): { lir.Return }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = builders.fn.rreturn(ty)
	end
	return array
end

local function arguments(ctx: Context, parameters: { hir.Parameter }): { lir.Argument }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.ty_id)
		array[index] = builders.fn.argument(ty, parameter.name)
	end
	return array
end

local function build_type(ctx: Context, decl_id: DeclId): lir.Type
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	if decl.generics then
		return nil :: any
	end

	return {
		type = "type",
		decl = decl,
		set = builders.ty.from_ty_id(ctx, decl.attributes, decl.ty_id),
	}
end

local function build_event(ctx: Context, decl_id: DeclId): lir.Event
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	return nil :: any
end

local function build_function(ctx: Context, decl_id: DeclId): lir.Function
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	return nil :: any
end

local function from_hir(hir: hir.Hir): lir.Lir
	local lir: Lir = {
		fns = {},
		globals = {},

		tys = {},
		types = {},
		events = {},
		functions = {},
	}

	local ctx: Context = context.create(hir, lir)

	for decl_id, decl in hir.types do
		lir.types[decl_id] = build_type(ctx, decl_id)
	end

	-- for decl_id, decl in hir.events do
	-- 	lir.events[decl_id] = build_event(ctx, decl_id)
	-- end

	-- for decl_id, decl in hir.functs do
	-- 	lir.functions[decl_id] = build_function(ctx, decl_id)
	-- end

	return lir
end

return table.freeze({
	from_hir = from_hir,
})
