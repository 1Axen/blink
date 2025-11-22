local globals = require("@builders/globals")
local hir = require("@hir")
local panic = require("@util/panic")
local ty = require("@ty")
local types = require("@lir/types")

type Lir = types.Lir
type Hir = hir.Hir

type TyId = ty.TyId
type FnId = types.FnId
type Global<T> = types.Global<T>
type RValue<T> = types.RValue<T>

export type FnSet = {
	read: FnId,
	write: FnId,
}

export type Context = {
	fn_id: number,
	fn_map: { [FnId]: types.Fn },
	globals: { [string]: RValue<any> },
	hashed_tys: { [number]: FnSet? },
	ty_fn_set_map: { [TyId]: FnSet },

	read hir: Hir,
}

local function create(hir: Hir): Context
	return {
		fn_id = 1,
		fn_map = {},
		globals = {},
		hashed_tys = {},
		ty_fn_set_map = {},
		hir = hir,
	}
end

local function next_fn_id(ctx: Context): FnId
	local fn_id = ctx.fn_id
	ctx.fn_id += 1
	return fn_id
end

local function store_fn(ctx: Context, fn: types.Fn, fn_id: FnId?): FnId
	fn_id = fn_id or next_fn_id(ctx)
	fn.id = fn_id
	ctx.fn_map[fn_id] = fn
	return fn_id
end

local function read_global<T>(ctx: Context, name: string): Global<T>
	if ctx.globals[name] == nil then
		return panic(`Global "{name}" doesn't exist`)
	end
	return globals.create(name)
end

local function write_global<T>(ctx: Context, name: string, rvalue: RValue<T>): Global<T>
	if ctx.globals[name] then
		return panic(`Duplicate write to global "{name}".`)
	end

	ctx.globals[name] = rvalue
	return globals.create(name)
end

local function fn_from_id(ctx: Context, fn_id: FnId): types.Fn
	local fn = ctx.fn_map[fn_id]
	if fn == nil then
		return panic("Expected fn id to point to a fn")
	end

	return fn
end

return table.freeze({
	create = create,
	store_fn = store_fn,
	next_fn_id = next_fn_id,
	fn_from_id = fn_from_id,
	read_global = read_global,
	write_global = write_global,
})
