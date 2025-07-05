local check_ty = require("@self/check_ty")
local flatten_ty = require("@self/flatten_ty")
local hir = require("@hir/types")
local simplify_ty = require("@self/simplify_ty")
local ty = require("@ty/types")

type Ty = ty.Ty
type Hir = hir.Hir

local function apply_constraints(hirr: Hir)
	for ty_id, ty in hirr.tys do
		ty = flatten_ty(hirr, ty)
		ty = simplify_ty(hirr, ty)
		check_ty(hirr, ty)
		hirr.tys[ty_id] = ty
	end
end

return table.freeze({
	apply = apply_constraints,
})
