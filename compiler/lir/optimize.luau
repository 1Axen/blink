--!strict
--!native
--!optimize 2

local lir = require("@lir/types")

local function optimize(lir: lir.Lir) end

return table.freeze({
	lir = optimize,
})
