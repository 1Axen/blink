--!strict
--!native
--!optimize 2

local hir = require("@hir/types")
local ast = require("@ast/types")

local build = require("./build")
local type_check = require("./type_check")
local flatten_tys = require("./flatten_tys")

export type Hir = hir.Hir

local function hir_from_files(files: {[number]: ast.Ast}): Hir
    local hir = build.from_files(files)
    type_check.hir(hir)
    flatten_tys.hir(hir)
    return hir
end

return table.freeze({
    from_files = hir_from_files,
})