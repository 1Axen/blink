local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local FFLAGS = {
	"LuauSolverV2",
	"LuauEagerGeneralization4",
	"LuauEnableWriteOnlyProperties",
	"LuauGeneralizationCannotMutateAcrossModules",
}

if not fs.isFile(".typedefs/globalTypes.None.d.luau") then
	local response = net.request(
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/refs/heads/main/scripts/globalTypes.None.d.luau"
	)

	assert(response.ok, response.statusMessage)

	fs.writeFile(".typedefs/globalTypes.None.d.luau", response.body)
end

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
table.insert(options, "./compiler/init.luau")
local result = process.exec("luau-lsp", options, { stdio = "forward" })

if result.code ~= 0 then
	process.exit(result.code)
end
