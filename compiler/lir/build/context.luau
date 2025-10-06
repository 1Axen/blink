local conversion = require("@util/conversion")
local globals = require("@builders/globals")
local hir = require("@hir/types")
local lir = require("@lir/types")
local panic = require("@util/panic")
local shuffle = require("@util/shuffle")
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
	reliable_ids: { number },
	unreliable_ids: { number },

	read hir: Hir,
	read lir: Lir,
}

local function create(hir: Hir, lir: Lir): Context
	local n_reliables = 0
	local n_unreliables = 0

	for _, event in hir.events do
		if event.type == "Reliable" then
			n_reliables += 1
		elseif event.type == "Unreliable" then
			n_unreliables += 1
		end
	end

	for _, funct in hir.functs do
		n_reliables += 1
	end

	local n_ids = math.max(n_reliables, n_unreliables, 256)
	local reliable_ids = table.create(n_ids, 0)
	local unreliable_ids = table.create(n_ids, 0)

	for index = 1, n_ids do
		local id = (index - 1)
		reliable_ids[index] = id
		unreliable_ids[index] = id
	end

	shuffle(reliable_ids)
	shuffle(unreliable_ids)

	return {
		index = 1,
		hashed_tys = {},
		reliable_ids = reliable_ids,
		unreliable_ids = unreliable_ids,

		hir = hir,
		lir = lir,
	}
end

local function next_fn_id(ctx: Context): FnId
	local fn_id = ctx.index
	ctx.index += 1
	return fn_id
end

local function next_event_id(ctx: Context, type: index<hir.Event, "type">): number
	local storage = type == "Reliable" and ctx.reliable_ids or ctx.unreliable_ids
	local id = table.remove(storage, #storage)
	if id == nil then
		return panic(`All "{type}" event ids were exhausted`)
	end
	return id
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
	next_event_id = next_event_id,
	read_global = read_global,
	write_global = write_global,
})
