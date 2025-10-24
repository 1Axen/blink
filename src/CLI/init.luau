--!native
--!optimize 2

---- Imports ----

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Compile = require("@self/Utility/Compile")
local Watch = require("@self/Utility/Watch")

---- Settings ----

type Argument = {
	Hidden: true?,
	Aliases: { string },
	Description: string,
}

local ARGUMENTS: { [string]: Argument } = {
	Help = {
		Aliases = { "-h", "--help" },
		Description = "Print help information",
	},
	Version = {
		Aliases = { "-v", "--version" },
		Description = "Print version information",
	},
	Watch = {
		Aliases = { "-w", "--watch" },
		Description = "Watch [CONFIG] for changes, automatically recompile upon one occuring",
	},
	Silent = {
		Aliases = { "-q", "--quiet" },
		Description = "Silence program output",
	},
	Compact = {
		Aliases = { "-c", "--compact" },
		Description = "Compacts error output, the full message is still printed out after a compacted version.",
	},
	YesToAll = {
		Aliases = { "-y", "--yes" },
		Description = "Accept all prompts",
	},
	OutputAst = {
		Hidden = true,
		Aliases = { "--ast" },
		Description = "Output the AST of [CONFIG]",
	},
	Statistics = {
		Hidden = true,
		Aliases = { "-S", "--stats" },
		Description = "Output compilation time statistics",
	},
}

---- Functions -----

local function Style(Text: string, Style: stdio.Style): string
	return `{stdio.style(Style)}{Text}{stdio.style("reset")}`
end

local function Color(Text: string, Color: stdio.Color): string
	return `{stdio.color(Color)}{Text}{stdio.color("reset")}`
end

local function PrintHelpMessage()
	print(Color(Style("USAGE:", "bold"), "yellow"))
	print("\tblink.exe [CONFIG] [OPTIONS]")
	print(Color(Style("OPTIONS:", "bold"), "yellow"))

	local Sorted: { Argument } = {}
	for _, Argument in ARGUMENTS do
		if not Argument.Hidden then
			table.insert(Sorted, Argument)
		end
	end

	table.sort(Sorted, function(a, b)
		return a.Aliases[1] < b.Aliases[1]
	end)

	for _, Argument in Sorted do
		print(
			`\t{stdio.color("green")}{table.concat(Argument.Aliases, ", ")}{stdio.color("reset")}\t{Argument.Description}`
		)
	end
end

---- Main ----

print(`{Color("Blink", "green")} {_G.VERSION or "DEBUG"}`)

local RawArguments = process.args
if #RawArguments < 1 then
	PrintHelpMessage()
	return
end

local Path = RawArguments[1]

--> Parse optional arguments
local Arguments = {}
for Key, Argument in ARGUMENTS do
	local IsSupplied = false
	for _, Alias in Argument.Aliases do
		if table.find(RawArguments, Alias) ~= nil then
			IsSupplied = true
			break
		end
	end

	Arguments[Key] = IsSupplied
end

if Arguments.Help then
	PrintHelpMessage()
	return
end

if Arguments.Version then
	return
end

if not Arguments.Watch then
	local CompileOptions: Compile.CompileOptions = {
		Debug = (_G.BUNDLED == nil) or Arguments.Statistics,
		Silent = Arguments.Silent,
		Compact = Arguments.Compact,
		YesToEverything = Arguments.YesToAll,
		OutputAbstractSyntaxTree = Arguments.OutputAst,
	}

	Compile.Compile(Path, CompileOptions)
else
	Watch.Watch(Path)
end
