--!native
--!optimize 2

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Parser = require("./Parser")
local Generator = require("./Generator/init.luau")

local function FormatTime(Time: number): string
	if Time < 1E-6 then
		return `{Time * 1E+9} ns`
	elseif Time < 0.001 then
		return `{Time * 1E+6} μs`
	elseif Time < 1 then
		return `{Time * 1000} ms`
	else
		return `{Time} seconds`
	end
end

local SourceParser = Parser.new()

local Arguments = process.args
if #Arguments ~= 1 then
    error(`Expected 1 argument, got {#Arguments} instead.`)
end

local SourcePath = Arguments[1]

stdio.write(stdio.color("cyan"))
print(`Reading source from {SourcePath}...`)
local Source = fs.readFile(SourcePath)

stdio.write(stdio.color("blue"))
print("Parsing source into AST...")
local ParseStart = os.clock()
local AbstractSyntaxTree, Options = SourceParser:Parse(Source)
local ParseTime = (os.clock() - ParseStart)

assert(Options.ClientOutput, "A client output path must be defined.")
assert(Options.ServerOutput, "A server output path must be defined.")

print("Generating output files...")
local GenerateStart = os.clock()
local ServerSource = Generator("Server", AbstractSyntaxTree, Options)
local ClientSource = Generator("Client", AbstractSyntaxTree, Options)
local GenerateTime = (os.clock() - GenerateStart)

fs.writeFile(`{Options.ServerOutput}`, ServerSource)
fs.writeFile(`{Options.ClientOutput}`, ClientSource)

stdio.write(stdio.color("green"))
print("Network files generated!")
stdio.write(stdio.color("white"))

if not _G.BUNDLED then
	print(`[DEBUG]: Parsed source in {FormatTime(ParseTime)}.`)
	print(`[DEBUG]: Generated files in {FormatTime(GenerateTime)}.`)
	print(`[DEBUG]: Completed everything in {FormatTime(ParseTime + GenerateTime)}.`)
end
