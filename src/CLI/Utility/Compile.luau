--!strict

---- Imports ----

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local Error = require("../../Modules/Error")
local Generator = require("../../Generator")
local GetDefinitionFilePath = require("./GetDefinitionFilePath")
local Parser = require("../../Parser")
local PathParser = require("../../Modules/Path")

---- Settings ----

export type CompileOptions = {
	Debug: boolean,
	Silent: boolean,
	Compact: boolean,
	YesToEverything: boolean,
	OutputAbstractSyntaxTree: boolean,
}

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function Message(Color: stdio.Color, Options: CompileOptions, ...)
	if Options.Silent then
		return
	end

	stdio.write(stdio.color(Color))
	print(...)
	stdio.write(stdio.color("reset"))
end

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

local function CreateDirectoryIfNotFound(Path: string, Options: CompileOptions)
	local Directory = PathParser.Directory(Path) or "./"
	if fs.isDir(Directory) then
		return
	end

	local Result = Options.YesToEverything
		or stdio.prompt("confirm", `Directory {Directory} doesn't exist, create directory?`)

	if Result then
		fs.writeDir(Directory)
		return
	end

	error("User refused prompt to create directory")
end

---- Public Functions ----

function Utility.Compile(Path: string, Options: CompileOptions)
	local FilePath = GetDefinitionFilePath(Path)
	Error.SetCompact(Options.Compact)

	Message("cyan", Options, `Reading source from {FilePath}...`)
	local Source = fs.readFile(FilePath)

	Message("blue", Options, "Parsing source into AST...")
	local FileDirectory = PathParser.Directory(FilePath) or "./"
	local SourceParser = Parser.new(FileDirectory, PathParser.NameWithExtension(FilePath))

	local ParseStart = os.clock()
	local AbstractSyntaxTree = SourceParser:Parse(Source)
	local ParseTime = (os.clock() - ParseStart)

	if Options.OutputAbstractSyntaxTree then
		print(AbstractSyntaxTree.Value.Options)
		print(AbstractSyntaxTree.Value.Declarations)
		return
	end

	local FileOptions = AbstractSyntaxTree.Value.Options
	local ClientOutputPath = FileOptions.ClientOutput
	local ServerOutputPath = FileOptions.ServerOutput

	assert(ClientOutputPath, "A client output path must be defined.")
	assert(ServerOutputPath, "A server output path must be defined.")

	local ClientTypescriptPath
	local ServerTypescriptPath

	do
		local Directory, Filename = PathParser.Components(ClientOutputPath)
		local TypescriptFilename = if Filename == "init" then "index" else Filename
		ClientOutputPath = `{Directory}/{Filename}.luau`
		ClientTypescriptPath = if PathParser.PathType(ClientOutputPath) == "absolute"
			then `{Directory}/{TypescriptFilename}.d.ts`
			else `{FileDirectory}{Directory}/{TypescriptFilename}.d.ts`
	end

	do
		local Directory, Filename = PathParser.Components(ServerOutputPath)
		local TypescriptFilename = if Filename == "init" then "index" else Filename
		ServerOutputPath = `{Directory}/{Filename}.luau`
		ServerTypescriptPath = if PathParser.PathType(ServerOutputPath) == "absolute"
			then `{Directory}/{TypescriptFilename}.d.ts`
			else `{FileDirectory}{Directory}/{TypescriptFilename}.d.ts`
	end

	local TypesOutput: string

	local ClientOutput: string
	local ServerOutput: string

	if PathParser.PathType(ClientOutputPath) == "absolute" then
		ClientOutput = ClientOutputPath
	else
		ClientOutput = `{FileDirectory}{ClientOutputPath}`
	end

	if PathParser.PathType(ServerOutputPath) == "absolute" then
		ServerOutput = ServerOutputPath
	else
		ServerOutput = `{FileDirectory}{ServerOutputPath}`
	end

	CreateDirectoryIfNotFound(ClientOutput, Options)
	CreateDirectoryIfNotFound(ServerOutput, Options)

	Message("blue", Options, "Generating output files...")
	local FilesStart = os.clock()

	local ServerGenerateStart = os.clock()
	local ServerSource = Generator.Generate("Server", AbstractSyntaxTree)
	local ServerGenerateTime = (os.clock() - ServerGenerateStart)

	local ClientGenerateStart = os.clock()
	local ClientSource = Generator.Generate("Client", AbstractSyntaxTree)
	local ClientGenerateTime = (os.clock() - ClientGenerateStart)

	local TypesSource: string?
	if FileOptions.TypesOutput then
		TypesOutput = if PathParser.PathType(Path) == "absolute"
			then FileOptions.TypesOutput
			else `{FileDirectory}{FileOptions.TypesOutput}`
		TypesSource = Generator.GenerateShared(AbstractSyntaxTree)
	end

	local ClientTypescriptSource: string?
	local ServerTypescriptSource: string?
	if FileOptions.Typescript then
		ClientTypescriptSource = Generator.GenerateTypescript("Client", AbstractSyntaxTree)
		ServerTypescriptSource = Generator.GenerateTypescript("Server", AbstractSyntaxTree)
	end

	local FilesTime = (os.clock() - FilesStart)
	fs.writeFile(ServerOutput, ServerSource)
	fs.writeFile(ClientOutput, ClientSource)

	if TypesSource and TypesOutput then
		CreateDirectoryIfNotFound(TypesOutput, Options)
		fs.writeFile(TypesOutput, TypesSource)
	end

	if ClientTypescriptSource and ServerTypescriptSource then
		fs.writeFile(ClientTypescriptPath, ClientTypescriptSource)
		fs.writeFile(ServerTypescriptPath, ServerTypescriptSource)
	end

	Message("green", Options, "Network files generated!")

	if Options.Debug and not Options.Silent then
		print(`[DEBUG]: Parsed source in {FormatTime(ParseTime)}.`)
		print(`[DEBUG]: Generated server luau in {FormatTime(ServerGenerateTime)}.`)
		print(`[DEBUG]: Generated client luau in {FormatTime(ClientGenerateTime)}.`)
		print(`[DEBUG]: Generated files in {FormatTime(FilesTime)}.`)
		print(`[DEBUG]: Completed everything in {FormatTime(ParseTime + FilesTime)}.`)
	end
end

---- Initialization ----

---- Connections ----

return Utility
