--!native
--!optimize 2

---- Imports ----

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Watch = require("./Utility/Watch.luau")
local Compile = require("./Utility/Compile.luau")

---- Settings ----

local ARGUMENTS = {
	Watch = {"--watch", "--w"},
	Silent = {"--silent", "--s"},
	YesToAll = {"--yes", "--y"},
	OutputAst = {"--ast"},
	Statistics = {"--stats"}
}

---- Functions -----

---- Main ----

print(`Blink {_G.VERSION or "DEBUG"}`)

local RawArguments = process.args
if #RawArguments < 1 then
    error(`Expected at least 1 argument.`)
end

local Path = RawArguments[1]

--> Parse optional arguments
local Arguments = {}
for Key, Aliases in ARGUMENTS do
	local IsSupplied = false
	for _, Alias in Aliases do
		if table.find(RawArguments, Alias) ~= nil then
			IsSupplied = true
			break
		end
	end

	Arguments[Key] = IsSupplied
end

if not Arguments.Watch then
	local CompileOptions: Compile.CompileOptions = {
		Debug = (_G.BUNDLED == nil) or Arguments.Statistics,
		Silent = Arguments.Silent,
		YesToEverything = Arguments.YesToAll,
		OutputAbstractSyntaxTree = Arguments.OutputAst
	}
	
	Compile.Compile(Path, CompileOptions)
else
	Watch.Watch(Path)
end






