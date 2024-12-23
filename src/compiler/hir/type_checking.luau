--!strict
--!native
--!optimize 2

local id = require("@compiler/id")
local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local ast = require("@compiler/structures/ast")

local codes = require("@compiler/config/codes")

local span = require("@util/span")
local panic = require("@util/panic")
local diagnostics = require("@util/diagnostics")

type Ty = ty.Ty
type Hir = hir.Hir
type Node = ast.Node

type TyId<T = Ty> = ty.TyId
type NodeId<T = Node> = ast.NodeId<T>

type TyKind = ty.TyKind

local function report_expect(node: {span: span.Span}, expected: string, got: string): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.InvalidType)
        .with_message(`Expected "{expected}", got "{got}" instead`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Expected "{expected}"`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of(node: {span: span.Span}, expected: {string}, got: string): never
    local fmted_expected = `"{table.concat(expected, "\", \"")}"`
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.InvalidType)
        .with_message(`Expected one of {fmted_expected}, got "{got}" instead`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Expected one of {fmted_expected}`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_optional_value(expr: ast.Expression): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.OptionalInMap)
        .with_message(`Optional value in map type`)
        .with_label(diagnostics.label.create(expr.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Make value non optional`)
        )
        .with_note("Optionals in maps aren't representable in Luau")
    .finish()
    .error()
end

local function report_optional_indexer(expr: ast.Expression): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.OptionalInMap)
        .with_message(`Optional indexer in map type`)
        .with_label(diagnostics.label.create(expr.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Make indexer non optional`)
        )
        .with_note("Optionals in maps aren't representable in Luau")
    .finish()
    .error()
end

local function ty_from_id(hir: Hir, ty_id: TyId): Ty
    local ty = hir.tys[ty_id]
    if ty == nil then
        return panic("Expected ty_id to point to a ty")
    end

    return ty
end

local function node_from_id(hir: Hir, node_id: NodeId): Node
    local node = hir.nodes[node_id]
    if node == nil then
        return panic("Expected node_id to point to a node")
    end

    return node
end

local function node_from_ty_id(hir: Hir, ty_id: TyId): Node
    local node_id = id.ty_id.to_node_id(ty_id)
    return node_from_id(hir, node_id)
end

local function ty_id_to_ty_kind(hir: Hir, ty_id: TyId): TyKind
    return ty_from_id(hir, ty_id).kind
end

local function assert_ty_kind(hir: Hir, ty_id: TyId, kind: TyKind)
    local ty_kind = ty_id_to_ty_kind(hir, ty_id)
    if ty_kind ~= kind then
        local node = node_from_ty_id(hir, ty_id)
        --TODO: Remove cast when Luau solver bug is fixed
        report_expect(node :: any, kind, ty_kind)
    end
end

local function assert_ty_kinds(hir: Hir, ty_id: TyId, kinds: {TyKind})
    local ty_kind = ty_id_to_ty_kind(hir, ty_id)
    if table.find(kinds, ty_kind) == nil then
        local node = node_from_ty_id(hir, ty_id)
        --TODO: Remove cast when Luau solver bug is fixed
        report_expect_one_of(node :: any, kinds :: {string}, ty_kind)
    end
end

local function type_check_hir(hir: Hir)

end

return table.freeze({
    type_check_hir = type_check_hir
})
