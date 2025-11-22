local check_ty = require("@self/check_ty")
local flatten_ty = require("@self/flatten_ty")
local simplify_ty = require("@self/simplify_ty")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type Hir = types.Hir

local function apply_constraints(hirr: Hir)
	for ty_id, ty in hirr.tys do
		ty = flatten_ty(hirr, ty)
		ty = simplify_ty(hirr, ty)
		hirr.tys[ty_id] = ty
	end

	for ty_id, ty in hirr.tys do
		check_ty(hirr, ty)
	end
end

return table.freeze({
	apply = apply_constraints,
})
