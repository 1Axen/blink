local hir = require("@hir/types")
local ty = require("@ty/types")

type Ty = ty.Ty
type Hir = hir.Hir

local function flatten_ty(hirr: Hir, ty: Ty): Ty
	while ty.kind == "optional" do
		local of_ty = hir.ty_from_id(hirr, ty.of)
		if of_ty.kind ~= "optional" then
			break
		end

		ty = of_ty
	end

	return ty
end

return flatten_ty
