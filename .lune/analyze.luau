local process = require("@lune/process")

local FFLAGS = {
	"LuauSolverV2",
	"LuauEagerGeneralization4",
	"LuauEnableWriteOnlyProperties",
	"LuauGeneralizationCannotMutateAcrossModules",
}

local options = {
	"analyze",
	`--base-luaurc=.luaurc`,
	"--platform=roblox",
	"--defs=.typedefs/globalTypes.None.d.luau",
	"--no-flags-enabled",
}

for index, fflag in FFLAGS do
	table.insert(options, `--flag:{fflag}=true`)
end

table.insert(options, "--ignore=vendor/**")
table.insert(options, "./compiler")
process.exec("luau-lsp", options, { stdio = "forward" })
