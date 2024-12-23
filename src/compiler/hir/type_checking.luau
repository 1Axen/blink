--!strict
--!native
--!optimize 2

local id = require("@compiler/id")
local ty = require("@compiler/types/ty")
local hir = require("@compiler/types/hir")
local ast = require("@compiler/types/ast")

local codes = require("@compiler/config/codes")

local span = require("@util/span")
local panic = require("@util/panic")("type checking")
local diagnostics = require("@util/diagnostics")

type Ty = ty.Ty
type Hir = hir.Hir
type Node = ast.Node

type TyId<T = Ty> = ty.TyId
type NodeId<T = Node> = ast.NodeId<T>

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

local function type_check_hir(hir: Hir)

end

return table.freeze({
    type_check_hir = type_check_hir
})
