--!strict
--!native
--!optimize 2

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
type DeclId<T> = hir.DeclId<T>

type Ty = ty.Ty
type TyId = ty.TyId

type Fn = lir.Fn
type FnId = lir.SetId

type Context = context.Context
type Builder = builders.Builder

local READ_PREFIX = "read_"
local WRITE_PREFIX = "write_"

local TYPE_PREFIX = "type_"
local EVENT_PREFIX = "event_"
local FUNCTION_PREFIX = "function_"

local function options_from_decl_id(ctx: Context, decl_id: DeclId<Decl>): options.FileOptions
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
		local ty = hir.ty_from_id(ctx.hir, parameter.value)
		array[index] = builders.fn.rreturn(ty)
	end
	return array
end

local function arguments(ctx: Context, parameters: { hir.Parameter }): { lir.Argument }
	local array = {}
	for index, parameter in parameters do
		local ty = hir.ty_from_id(ctx.hir, parameter.value)
		array[index] = builders.fn.argument(ty, parameter.name)
	end
	return array
end

local function build_type(ctx: Context, decl_id: DeclId<hir.Type>): lir.Type
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	if decl.generics then
		return nil :: any
	end

	local ty_id = decl.ty
	local ty = hir.ty_from_id(ctx.hir, ty_id)

	local rets = { builders.fn.rreturn(ty) }
	local args = { builders.fn.argument(ty) }
	local attributes = decl.attributes

	local read_props: types.ReadProps = {
		ctx = ctx,
		attributes = attributes,
	}

	local read_fn = builders.fn.create(`read_{decl.name}`, args, rets, function(block)
		local value_register = builders.ty.read(read_props, block, ty_id)
		block:rtrn({ value_register :: lir.RValue<any> })
	end)

	local write_props: types.WriteProps = {
		ctx = ctx,
		validate = true,
		attributes = attributes,
	}

	local write_fn = builders.fn.create(`write_{decl.name}`, args, rets, function(block)
		builders.ty.write(write_props, block, ty_id, block:argument(1))
	end)

	return {
		type = "type",
		decl = decl,
		set = context.fn_set(ctx, ty_id, read_fn, write_fn),
	}
end

local function build_event(ctx: Context, decl_id: DeclId<hir.Event>): lir.Event
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	return nil :: any
end

local function build_function(ctx: Context, decl_id: DeclId<hir.Function>): lir.Function
	local decl = hir.decl_from_id(ctx.hir, decl_id)
	return nil :: any
end

local function from_hir(hir: hir.Hir): lir.Lir
	local lir: Lir = {
		sets = {},
		types = {},
		events = {},
		functions = {},
	}

	local ctx: Context = context.create(hir, lir)

	for decl_id, decl in hir.decls do
		local kind = decl.kind
		if kind == "type" then
			lir.types[decl_id] = build_type(ctx, decl_id :: DeclId<hir.Type>)
		elseif kind == "event" then
			lir.events[decl_id] = build_event(ctx, decl_id :: DeclId<hir.Event>)
		elseif kind == "function" then
			lir.functions[decl_id] = build_function(ctx, decl_id :: DeclId<hir.Function>)
		else
			strong_exhaustive_match(kind)
		end
	end

	return lir
end

return table.freeze({
	from_hir = from_hir,
})
