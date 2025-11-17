--!strict
--!native
--!optimize 2

local ast = require("@ast/types")
local hir = require("@hir/types")
local ty = require("@ty/types")

local report = require("@hir/report")

type Ty = ty.Ty
type Hir = hir.Hir
type Node = ast.Node
type TyId<T = Ty> = ty.TyId<T>
type TyKind = ty.TyKind
type NodeId = ast.NodeId

local follow = hir.follow
local ty_from_id = hir.ty_from_id
local node_from_id = hir.node_from_id

local function node_from_ty_id(hir: Hir, ty_id: TyId): Node
	return node_from_id(hir, ty_id :: NodeId)
end

local function ty_id_to_ty_kind(hir: Hir, ty_id: TyId): TyKind
	return ty_from_id(hir, ty_id).kind
end

local function assert_ty_kind<T>(hir: Hir, ty_id: TyId<T>, kind: TyKind)
	local ty_kind = ty_id_to_ty_kind(hir, ty_id)
	if ty_kind ~= kind then
		local node = node_from_ty_id(hir, ty_id)
		report.expect(node, kind, ty_kind)
	end
end

local function assert_vector_axis_ty<T>(hir: Hir, ty_id: TyId<T>)
	local ty: Ty = ty_from_id(hir, ty_id)
	if ty.kind ~= "numeral" then
		return
	end

	local size = tonumber(ty.size) :: number
	local format = ty.format

	if (format == "f" and size > 32) or (format ~= "f" and size > 24) then
		local node = node_from_ty_id(hir, ty_id)
		report.cannot_represent_vector_axis(node)
	end
end

local function assert_ty_kinds<T>(hir: Hir, ty_id: TyId<T>, kinds: { TyKind })
	local ty_kind = ty_id_to_ty_kind(hir, ty_id)
	if table.find(kinds, ty_kind) == nil then
		local node = node_from_ty_id(hir, ty_id)
		report.expect_one_of(node, kinds :: { string }, ty_kind)
	end
end

local function check_map(hir: Hir, ty: ty.Map)
	local index = ty_from_id(hir, ty.index)
	if index.kind == "optional" then
		local node = node_from_ty_id(hir, ty.index)
		report.optional_indexer(node)
	end

	local value = ty_from_id(hir, ty.value)
	if value.kind == "optional" then
		local node = node_from_ty_id(hir, ty.value)
		report.optional_value(node)
	end
end

local function check_union(hir: Hir, ty: ty.Union)
	local left = ty_from_id(hir, ty.left)
	local right = ty_from_id(hir, ty.right)

	left = follow(hir, left)
	right = follow(hir, right)

	if left.kind ~= "struct" and left.kind ~= "union" then
		--TODO: Remove cast (Luau bug)
		local node = node_from_ty_id(hir, ty.left :: TyId)
		report.invalid_intersection(node, left.kind, left.kind, right.kind)
	elseif right.kind ~= "struct" and right.kind ~= "union" then
		--TODO: Remove cast (Luau bug)
		local node = node_from_ty_id(hir, ty.right :: TyId)
		report.invalid_intersection(node, right.kind, left.kind, right.kind)
	end
end

local function check_vector(hir: Hir, ty: ty.Vector)
	if ty.x then
		assert_ty_kinds(hir, ty.x, { "numeral", "number_literal" })
		assert_vector_axis_ty(hir, ty.x)
	end

	if ty.y then
		assert_ty_kinds(hir, ty.y, { "numeral", "number_literal" })
		assert_vector_axis_ty(hir, ty.y)
	end

	if ty.z then
		assert_ty_kinds(hir, ty.z, { "numeral", "number_literal" })
		assert_vector_axis_ty(hir, ty.z)
	end
end

local function check_cframe(hir: Hir, ty: ty.CFrame)
	if ty.position then
		assert_ty_kind(hir, ty.position, "numeral")
		assert_vector_axis_ty(hir, ty.position)
	end

	if ty.rotation then
		assert_ty_kind(hir, ty.rotation, "numeral")
	end
end

local function check_instance(hir: Hir, ty: ty.Instance)
	if ty.class then
		assert_ty_kind(hir, ty.class, "string_literal")
	end
end

local function check_roblox_enum(hir: Hir, ty: ty.Enum)
	if ty.type then
		assert_ty_kind(hir, ty.type, "string_literal")
	end
end

local function check_ty(hir: Hir, ty: ty.Ty)
	if ty.kind == "map" then
		check_map(hir, ty)
	elseif ty.kind == "union" then
		check_union(hir, ty)
	elseif ty.kind == "vector" then
		check_vector(hir, ty)
	elseif ty.kind == "cframe" then
		check_cframe(hir, ty)
	elseif ty.kind == "instance" then
		check_instance(hir, ty)
	elseif ty.kind == "roblox_enum" then
		check_roblox_enum(hir, ty)
	end
end

return check_ty
