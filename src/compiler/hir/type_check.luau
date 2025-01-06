--!strict
--!native
--!optimize 2

local id = require("@compiler/id")
local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local ast = require("@compiler/structures/ast")

local report = require("./report")

type Ty = ty.Ty
type Hir = hir.Hir
type Node = ast.Node

type TyId<T = Ty> = ty.TyId
type NodeId<T = Node> = ast.NodeId<T>

type TyKind = ty.TyKind

local ty_from_id = hir.ty_from_id
local node_from_id = hir.node_from_id

local function node_from_ty_id(hir: Hir, ty_id: TyId): Node
    local node_id = id.ty_id.to_node_id(ty_id)
    return node_from_id(hir, node_id)
end

local function ty_id_to_ty_kind(hir: Hir, ty_id: TyId): TyKind
    return ty_from_id(hir, ty_id).kind
end

local function ty_to_base_ty_kind(ty: Ty): TyKind
    if ty.kind == "optional" then
        return ty_to_base_ty_kind(ty.of)
    elseif ty.kind == "generic_type" then
        return ty_to_base_ty_kind(ty.def)
    end

    return ty.kind
end

local function is_ty_of_kind(ty: Ty, kind: TyKind): boolean
    return ty_to_base_ty_kind(ty) == kind
end

local function assert_ty_kind(hir: Hir, ty_id: TyId, kind: TyKind)
    local ty_kind = ty_id_to_ty_kind(hir, ty_id)
    if ty_kind ~= kind then
        local node = node_from_ty_id(hir, ty_id)
        --TODO: Remove cast when Luau solver bug is fixed
        report.expect(node :: any, kind, ty_kind)
    end
end

local function assert_ty_kinds(hir: Hir, ty_id: TyId, kinds: {TyKind})
    local ty_kind = ty_id_to_ty_kind(hir, ty_id)
    if table.find(kinds, ty_kind) == nil then
        local node = node_from_ty_id(hir, ty_id)
        --TODO: Remove cast when Luau solver bug is fixed
        report.expect_one_of(node :: any, kinds :: {string}, ty_kind)
    end
end

local function ty_map(hir: Hir, ty: ty.Map)
    local index = ty_from_id(hir, ty.index)
    if index.kind == "optional" then
        local node_id = id.ty_id.to_node_id(ty.index)
        local node = node_from_id(hir, node_id)
        --TODO: Remove cast (Luau bug)
        report.optional_indexer(node :: any)
    end

    local value = ty_from_id(hir, ty.value)
    if value.kind == "optional" then
        local node_id = id.ty_id.to_node_id(ty.value)
        local node = node_from_id(hir, node_id)
        --TODO: Remove cast (Luau bug)
        report.optional_value(node :: any)
    end
end

local function ty_union(hir: Hir, ty: ty.Union)
    local left = ty_from_id(hir, ty.left)
    local right = ty_from_id(hir, ty.right)

    local left_kind = ty_to_base_ty_kind(left)
    local right_kind = ty_to_base_ty_kind(right)

    if left_kind ~= "struct" then
        local node_id = id.ty_id.to_node_id(ty.left)
        local node = node_from_id(hir, node_id)
        --TODO: Remove cast (Luau bug)
        report.invalid_union(node :: any, left_kind, left_kind, right_kind)
    elseif right_kind ~= "struct" then
        local node_id = id.ty_id.to_node_id(ty.right)
        local node = node_from_id(hir, node_id)
        --TODO: Remove cast (Luau bug)
        report.invalid_union(node :: any, right_kind, left_kind, right_kind)
    end
end

local function ty_vector(hir: Hir, ty: ty.Vector)
    if ty.x then
        assert_ty_kinds(hir, ty.x, {"numeral", "number_literal"})
    end

    if ty.y then
        assert_ty_kinds(hir, ty.y, {"numeral", "number_literal"})
    end

    if ty.z then
        assert_ty_kinds(hir, ty.z, {"numeral", "number_literal"})
    end
end

local function ty_cframe(hir: Hir, ty: ty.CFrame)
    if ty.position then
        assert_ty_kind(hir, ty.position, "numeral")
    end

    if ty.rotation then
        assert_ty_kind(hir, ty.rotation, "numeral")
    end
end

local function ty_instance(hir: Hir, ty: ty.Instance)
    if ty.class then
        assert_ty_kind(hir, ty.class, "string_literal")
    end
end

local function ty_roblox_enum(hir: Hir, ty: ty.Enum)
    if ty.type then
        assert_ty_kind(hir, ty.type, "string_literal")
    end
end

local function check_ty(hir: Hir, ty: ty.Ty)
    if ty.kind == "map" then
        ty_map(hir, ty)
    elseif ty.kind == "union" then
        ty_union(hir, ty)
    elseif ty.kind == "vector" then
        ty_vector(hir, ty)
    elseif ty.kind == "cframe" then
        ty_cframe(hir, ty)
    elseif ty.kind == "instance" then
        ty_instance(hir, ty)
    elseif ty.kind == "roblox_enum" then
        ty_roblox_enum(hir, ty)
    end
end

local function type_check_hir(hir: Hir)
    for ty_id, ty in hir.tys do
        check_ty(hir, ty)
    end
end

return table.freeze({
    hir = type_check_hir
})
