--!strict
--!native
--!optimize 2

local ast = require("@ast/types")
local hir = require("@hir/types")

local build = require("@self/build")
local constraints = require("@self/constraints")

export type Hir = hir.Hir

local function hir_from_files(files: { [number]: ast.Ast }): Hir
	local hirr = build.from_files(files)
	constraints.apply(hirr)
	return hirr
end

return table.freeze({
	from_files = hir_from_files,
})
