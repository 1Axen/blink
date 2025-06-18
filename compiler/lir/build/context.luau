local hir = require("@hir/types")
local id = require("@compiler/id")
local lir = require("@lir/types")
local ty = require("@ty/types")

type Lir = lir.Lir
type Hir = hir.Hir

type TyId = ty.TyId

export type Context = {
	read hir: Hir,
	read lir: Lir,
}

local function create(hir: Hir, lir: Lir): Context
	return table.freeze({
		hir = hir,
		lir = lir,
	})
end

local function fn_set(ctx: Context, ty_id: TyId, read: lir.Fn, write: lir.Fn): lir.SetId
	local set_id = id.to_set_id(ty_id)
	local set: lir.Set = {
		read = read,
		write = write,
	}

	ctx.lir.sets[set_id] = set
	return set_id
end

return table.freeze({
	create = create,
	fn_set = fn_set,
})
