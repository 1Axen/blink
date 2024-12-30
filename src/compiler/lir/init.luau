--!strict
--!native
--!optimize 2

local hir = require("@compiler/structures/hir")
local lir = require("@compiler/structures/lir")

local build = require("./build")
local optimize = require("./optimize")

local function lir_from_hir(hir: hir.Hir): lir.Lir
    local lir = build.lir(hir)
    optimize.lir(lir)
    return lir
end
