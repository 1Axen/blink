--!strict
--!native
--!optimize 2

local ty = require("@structures/ty")
local hir = require("@structures/hir")
local ast = require("@structures/ast")

local build = require("./build")
local type_check = require("./type_check")
local flatten_tys = require("./flatten_tys")

local function hir_from_files(files: {[number]: ast.Ast}): hir.Hir
    local hir = build.from_files(files)
    type_check.hir(hir)
    flatten_tys.hir(hir)
    return hir
end

return table.freeze({
    from_files = hir_from_files,
})