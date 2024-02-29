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
if #Arguments < 1 then
    error(`Expected at least 1 argument.`)
end

local SourcePath = Arguments[1]

print(`Blink {_G.VERSION or "DEBUG"}`)
stdio.write(stdio.color("cyan"))
print(`Reading source from {SourcePath}...`)
local Source = fs.readFile(SourcePath)

stdio.write(stdio.color("blue"))
print("Parsing source into AST...")
local ParseStart = os.clock()
local AbstractSyntaxTree = SourceParser:Parse(Source)
local ParseTime = (os.clock() - ParseStart)

if table.find(Arguments, "ast") then
	print(AbstractSyntaxTree.Value.Options)
	print(AbstractSyntaxTree.Value.Declarations)
	return
end

local Options = AbstractSyntaxTree.Value.Options
assert(Options.ClientOutput, "A client output path must be defined.")
assert(Options.ServerOutput, "A server output path must be defined.")

print("Generating output files...")
local GenerateStart = os.clock()
local ServerSource = Generator.Generate("Server", AbstractSyntaxTree)
local ClientSource = Generator.Generate("Client", AbstractSyntaxTree)

local TypesSource: string?;
if Options.TypesOutput then
	TypesSource = Generator.GenerateTypeDefinitions("Server", AbstractSyntaxTree, Options)
end

local GenerateTime = (os.clock() - GenerateStart)

fs.writeFile(`{Options.ServerOutput}`, ServerSource)
fs.writeFile(`{Options.ClientOutput}`, ClientSource)

if TypesSource then
	fs.writeFile(`{Options.TypesOutput}`, TypesSource)
end

stdio.write(stdio.color("green"))
print("Network files generated!")
stdio.write(stdio.color("reset"))

if not _G.BUNDLED then
	print(`[DEBUG]: Parsed source in {FormatTime(ParseTime)}.`)
	print(`[DEBUG]: Generated files in {FormatTime(GenerateTime)}.`)
	print(`[DEBUG]: Completed everything in {FormatTime(ParseTime + GenerateTime)}.`)
end