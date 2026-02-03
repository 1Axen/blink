local cli_builder = require("@packages/cli_builder")
local colorful = require("@vendor/colorful")
local compilation = require("@compiler/config/compilation")
local compiler = require("@compiler")
local fs = require("@util/fs")
local hir = require("@compiler/hir")
local path = require("@util/path")
local printext = require("@util/printext")
local process = require("@lute/process")
local system = require("@lute/system")

type Path = path.Path
type Profile = compilation.Profile

type Context = {
	read globalOptions: { [string]: any },
	read commandOptions: { [string]: any },
	read commandArguments: { [string]: any },
}

local NAME = colorful.color.green("Blink")
local VERSION = "1.0.0"
local HEADER = `{NAME} {VERSION}`

local VALID_PROFILES: { [Profile]: true } = {
	dev = true :: true,
	test = true :: true,
	debug = true :: true,
	release = true :: true,
}

local cli = cli_builder.cli
local option = cli_builder.option
local command = cli_builder.command
local argument = cli_builder.argument

local args = { ... }
table.remove(args, 1)

if system.os == "Windows_NT" then
	process.system("chcp 65001")
end

local function write_with_logging(file_path: Path, contents: string)
	local str_path = path.to_string(file_path)
	local write_result = fs.write_string_to_file(file_path, contents)

	if not write_result.ok then
		printext.error(`Encountered an IO error while writing "{str_path}":\n{write_result.error.message}`)
		return
	end

	printext.info(`Wrote output to: "{str_path}"`)
end

local function on_compile(context: Context)
	local yes_all: boolean = context.globalOptions.yes
	local verbose: boolean = context.globalOptions.verbose

	local print_hir: boolean = context.commandOptions.hir

	local watch: boolean = context.commandOptions.watch
	local profile: Profile = context.commandOptions.profile

	if VALID_PROFILES[profile] ~= true then
		error(`Unknown compiler profile "{profile}".`)
	end

	local input: string = context.commandArguments.input
	local input_path = path.from_string(input)
	input_path = path.with_extension(input_path, "blink")

	print(HEADER)

	if fs.is_file(input_path) == false then
		error(`Unable to find entry file "{input}"`)
	end

	if verbose then
		printext.verbose(`Yes to all? {yes_all}`, `Watch? {watch}`)
	end

	printext.info(`Compiling "{path.to_string(input_path)}" in "{profile}" profile...`)
	local compilation_result = compiler.compile_from_path(input_path, {
		time = false,
		verbose = verbose,
		profile = profile,
	})

	if not compilation_result.ok then
		printext.error(`Encountered an IO error while compiling: {compilation_result.error.message}`)
		return
	end

	local value = compilation_result.value
	if print_hir then
		print(hir.format(value.hir))
	end

	local targets = value.targets
	local input_directory = path.strip_file_name(input_path)

	for _, target in targets :: { [string]: index<typeof(targets), keyof<typeof(targets)>> } do
		assert(target)
		local output_path = path.join(input_directory, target.path)
		output_path = path.with_extension(output_path, "luau")
		write_with_logging(output_path, target.contents)
	end
end

--stylua: ignore
cli.new()
	:setName(NAME)
	:setVersion(VERSION)
	:setDescription("An IDL for defining structured data that compiles to fast Luau buffer serdes.")
	:setGitRepository("https://github.com/1Axen/blink")
	:setEpilog("Example: blink compile <file>")
	:addOption(
		option.new()
			:setName("verbose")
			:setDescription("Enable verbose logging.")
			:setType("boolean")
			:setDefaultValue(false)
			:build()
	)
	:addOption(
		option.new()
			:setName("yes")
			:addAlias("y")
			:setDescription("Accept all prompts.")
			:setType("boolean")
			:setDefaultValue(false)
			:build()
	)
	:addCommand(
		command.new()
			:setName("compile")
			:setDescription("Compiles entry point and resolved dependencies into Luau code.")
			:setCallback(on_compile)
			:addArgument(
				argument.new()
					:setName("input")
					:setDescription("Path to the compilation entry point file.")
					:setRequired(true)
					:setType("string")
					:build()
			)
			:addOption(
				option.new()
					:setName("hir")
					:setDescription("Output a formatted HIR to the stdout")
					:setType("boolean")
					:setDefaultValue(false)
					:build()
			)
			:addOption(
				option.new()
					:setName("watch")
					:addAlias("w")
					:setDescription("Watch the blink project for changes, and recompile upon one being made.")	
					:setType("boolean")
					:setDefaultValue(false)
					:build()
			)
			:addOption(
				option.new()
					:setName("profile")
					:addAlias("p")
					:setDescription("Profile to use for the compilation")	
					:setType("string")
					:setDefaultValue("dev")
					:build()
			)
			:build()
	)
	:configure({
		ansiColorEnabled = true
	})
	:run(args)