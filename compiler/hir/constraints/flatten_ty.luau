local lookup = require("@hir/lookup")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type Hir = types.Hir

local function flatten_ty(hirr: Hir, ty: Ty): Ty
	while ty.kind == "optional" do
		local of_ty = lookup.ty_from_id(hirr, ty.of)
		if of_ty.kind ~= "optional" then
			break
		end

		ty = of_ty
	end

	return ty
end

return flatten_ty
