--!strict
--!native
--!optimize 2

local ast = require("@ast/types")
local hir = require("@hir/types")
local ty = require("@ty/types")

type Ty = ty.Ty
type Hir = hir.Hir
type Node = ast.Node

type TyId<T = Ty> = ty.TyId<T>
type NodeId<T = Node> = ast.NodeId<T>

type TyKind = ty.TyKind

local ty_from_id = hir.ty_from_id

local function flatten_optional(hir: Hir, optional: ty.Optional): ty.Optional
	local of = ty_from_id(hir, optional.of)
	if of.kind ~= "optional" then
		return optional
	end

	return flatten_optional(hir, of)
end

local function flatten_hir(hir: Hir)
	for ty_id, ty in hir.tys do
		local final_ty = ty
		if ty.kind == "optional" then
			final_ty = flatten_optional(hir, ty)
		end

		hir.tys[ty_id] = final_ty
	end
end

return table.freeze({
	hir = flatten_hir,
})
