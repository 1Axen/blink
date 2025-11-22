--!strict
--!native
--!optimize 2

local types = require("@lir/types")

local function optimize(lir: types.Lir) end

return table.freeze({
	lir = optimize,
})
