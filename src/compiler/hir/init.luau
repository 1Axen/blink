--!strict
--!native
--!optimize 2

local ty = require("@compiler/types/ty")
local hir = require("@compiler/types/hir")
local ast = require("@compiler/types/ast")

local lowering = require("./lowering")

return table.freeze({
    from_ast = lowering.lower_ast_to_hir,
})