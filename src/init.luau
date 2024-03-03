--!native
--!optimize 2

---- Imports ----
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Parser = require("./Parser")
local Generator = require("./Generator/init.luau")

---- Functions -----

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

local Extensions = {"", ".txt", ".blink"}
local function TryLocateSourceFile(Path: string): string
	for _, Extension in Extensions do
		local Temporary = `{Path}{Extension}`
		print(Temporary)
		if fs.isFile(Temporary) then
			return Temporary
		end
	end

	error(`Unable to locate source file at {Path}`)
end

local function ExtractDirectory(Path: string): string
	return string.match(Path, "(.-)%/[^%/]*$") or "./"
end

local function CreateDirectoryIfNotFound(Path: string)
    local Directory = ExtractDirectory(Path)
    if fs.isDir(Directory) then
       return   
    end

	local Result = stdio.prompt("confirm", `Directory {Directory} doesn't exist, create directory?`)
	if Result then
		fs.writeDir(Directory)
		return
	end

	error("User refused prompt to create directory")
end

---- Constants ----

local Arguments = process.args
if #Arguments < 1 then
    error(`Expected at least 1 argument.`)
end

local SourcePath = TryLocateSourceFile(Arguments[1])
local SourceParser = Parser.new()
local SourceDirectory = ExtractDirectory(SourcePath)

---- Main ----

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

local TypesOutput: string;
local ClientOutput = `{SourceDirectory}/{Options.ClientOutput}`
local ServerOutput = `{SourceDirectory}/{Options.ServerOutput}`

CreateDirectoryIfNotFound(ClientOutput)
CreateDirectoryIfNotFound(ServerOutput)

print("Generating output files...")
local GenerateStart = os.clock()
local ServerSource = Generator.Generate("Server", AbstractSyntaxTree)
local ClientSource = Generator.Generate("Client", AbstractSyntaxTree)

local TypesSource: string?;
if Options.TypesOutput then
	TypesOutput = `{SourceDirectory}/{Options.TypesOutput}`
	TypesSource = Generator.GenerateTypeDefinitions("Server", AbstractSyntaxTree)
end

local GenerateTime = (os.clock() - GenerateStart)
fs.writeFile(ServerOutput, ServerSource)
fs.writeFile(ClientOutput, ClientSource)

if TypesSource and TypesOutput then
	CreateDirectoryIfNotFound(TypesOutput)
	fs.writeFile(TypesOutput, TypesSource)
end

stdio.write(stdio.color("green"))
print("Network files generated!")
stdio.write(stdio.color("reset"))

if not _G.BUNDLED then
	print(`[DEBUG]: Parsed source in {FormatTime(ParseTime)}.`)
	print(`[DEBUG]: Generated files in {FormatTime(GenerateTime)}.`)
	print(`[DEBUG]: Completed everything in {FormatTime(ParseTime + GenerateTime)}.`)
end