--!strict
--!native
--!optimize 2

local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local ast = require("@compiler/structures/ast")

local build = require("./build")
local type_check = require("./type_check")

local function hir_from_ast(ast: ast.Ast): hir.Hir
    local hir = build.hir(ast)
    type_check.hir(hir)
    return hir
end

return table.freeze({
    from_ast = hir_from_ast,
})