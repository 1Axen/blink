--!strict
--!native
--!optimize 2

local hir = require("@structures/hir")
local lir = require("@structures/lir")

local function optimize(lir: lir.Lir)
    
end

return table.freeze({
    lir = optimize
})