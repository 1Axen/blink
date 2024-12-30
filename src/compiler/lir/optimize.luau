--!strict
--!native
--!optimize 2

local hir = require("@compiler/structures/hir")
local lir = require("@compiler/structures/lir")

local function optimize(lir: lir.Lir)
    
end

return table.freeze({
    lir = optimize
})