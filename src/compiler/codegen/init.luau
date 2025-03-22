--!strict
--!native
--!optimize 2

local lir = require("@compiler/lir")
local compilation = require("@config/compilation")

local function from_lir(lir: lir.Lir, target: compilation.Target): string
    return ""
end

return table.freeze({
    from_lir = from_lir
})