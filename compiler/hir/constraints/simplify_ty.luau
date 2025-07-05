local hir = require("@hir/types")
local ty = require("@ty/types")

type Ty = ty.Ty
type Hir = hir.Hir

local function simplify_ty(hirr: Hir, tyy: Ty): Ty
	if tyy.kind == "reference" then
		local to_ty = hir.ty_from_id(hirr, tyy.to)
		if not ty.is_possibly_recursive(to_ty) then
			return to_ty
		elseif to_ty.kind == "generic_type" then
			return ty.generic_type(to_ty.body, tyy.args)
		end
	end

	return tyy
end

return simplify_ty
