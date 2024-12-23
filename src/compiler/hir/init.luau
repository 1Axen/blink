--!strict
--!native
--!optimize 2

local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local ast = require("@compiler/structures/ast")

local lowering = require("./lowering")
local type_checking = require("./type_checking")

local function hir_from_ast(ast: ast.Ast): hir.Hir
    local hir = lowering.lower_ast_to_hir(ast)
    type_checking.type_check_hir(hir)
    return hir
end

return table.freeze({
    from_ast = hir_from_ast,
})