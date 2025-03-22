--!strict
--!native
--!optimize 2

local hir = require("@structures/hir")
local lir = require("@structures/lir")

local build = require("./build")
local optimize = require("./optimize")

export type Lir = lir.Lir

local function lir_from_hir(hir: hir.Hir): Lir
    local lir = build.from_hir(hir)
    optimize.lir(lir)
    return lir
end

return table.freeze({
    from_hir = lir_from_hir,
})