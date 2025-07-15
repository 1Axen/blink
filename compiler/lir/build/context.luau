local hir = require("@hir/types")
local lir = require("@lir/types")
local panic = require("@util/panic")
local ty = require("@ty/types")

type Lir = lir.Lir
type Hir = hir.Hir

type TyId = ty.TyId
type FnId = lir.FnId
type Global<T> = lir.Global<T>
type RValue<T> = lir.RValue<T>

export type Context = {
	index: number,
	hashed_tys: { [number]: lir.FnSet? },

	read hir: Hir,
	read lir: Lir,
}

local function create(hir: Hir, lir: Lir): Context
	return {
		index = 1,
		hashed_tys = {},

		hir = hir,
		lir = lir,
	}
end

local function next_fn_id(ctx: Context): FnId
	local fn_id = ctx.index
	ctx.index += 1
	return fn_id
end

local function store_fn(ctx: Context, fn: lir.Fn, fn_id: FnId?): FnId
	local lirr = ctx.lir
	fn_id = fn_id or next_fn_id(ctx)
	fn.id = fn_id
	lirr.fns[fn_id] = fn
	return fn_id
end

local function read_global<T>(ctx: Context, name: string): Global<T>
	if ctx.lir.globals[name] == nil then
		return panic(`Global "{name}" doesn't exist`)
	end
	return globals.create(name)
end

local function write_global<T>(ctx: Context, name: string, rvalue: RValue<T>): Global<T>
	local lirr = ctx.lir
	if lirr.globals[name] then
		return panic(`Duplicate write to global "{name}".`)
	end

	lirr.globals[name] = rvalue
	return globals.create(name)
end

return table.freeze({
	create = create,
	store_fn = store_fn,
	next_fn_id = next_fn_id,
	read_global = read_global,
	write_global = write_global,
})
