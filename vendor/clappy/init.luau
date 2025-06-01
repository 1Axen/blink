local types = require("@self/types")
local parser = require("@self/parser")
local colorful = require("@vendor/colorful")

local process = require("@lune/process")

export type Metadata = {
	description: string,
	author: string,
	version: string,

	afterHelp: string,
}?

local function runTypeObject<T>(object: types.TypeObject<T>, value: string): { valid: true, value: T } | { valid: false }
	local isValid = object.validator(value)
	if not isValid then
		return { valid = false }
	end

	return { valid = true, value = object.convert(value) }
end

local function handleCommand(command: types.CommandInfo, args: { string }, opts: { [string]: string })
	local parameters = {}
	local options = {}

	for index, parameter in command.parameters do
		local result = runTypeObject(parameter.type, args[index])
		if not result.valid then
			error(`invalid value for parameter "{parameter.name}"`)
		end

		parameters[parameter.name] = result.value
	end

	for _, opt in command.opts do
		local result = runTypeObject(opt.type, opts[opt.name])
		if not result.valid then
			error(`invalid value for option "{opt.name}"`)
		end

		options[opt.name] = result.value
	end

	command.runner(parameters, options)
end

local cli = {}
export type Identity = typeof(setmetatable(
	{} :: {
		_metadata: Metadata?,
		_name: string,

		_palette: {
			primary: colorful.Styler,
			secondary: colorful.Styler,
			tertiary: colorful.Styler,
		},

		rootCommand: types.CommandInfo?,
		subcommands: { [string]: types.CommandInfo }?,
		globalOpts: { [string]: { name: string, description: string, runner: () -> () } }?,
	},
	{
		__index = cli,
	}
))

local function constructor(name: string): Identity
	local self = setmetatable({}, { __index = cli })

	self._name = name
	self._palette = {
		primary = colorful.color.green,
		secondary = colorful.combineStyles({ colorful.color.cyanBright }),
		tertiary = colorful.combineStyles({}),
	}

	self._config = {
		subcommandRequired = false,
	}

	return self
end

function cli.palette(
	self: Identity,
	palette: { primary: colorful.Styler, secondary: colorful.Styler, tertiary: colorful.Styler }
)
	self._palette = palette
	return self
end

function cli.metadata(self: Identity, metadata: Metadata)
	self._metadata = metadata
	return self
end

function cli.defineGlobalOpt<T>(self: Identity, name: string, description: string, runner: () -> ())
	if not self.globalOpts then
		self.globalOpts = {}
	end

	(self.globalOpts :: any)[name] = {
		name = name,
		description = description,
		runner = runner,
	}
	return self
end

function cli.defineSubcommand(self: Identity, command: types.CommandInfo)
	for name in command.opts do
		if name == "help" or (self.globalOpts and self.globalOpts[name]) then
			error(`reserved option name: "{name}"`)
		end
	end

	if not self.subcommands then
		self.subcommands = {}
	end

	(self.subcommands :: any)[command.name] = command
	return self
end

function cli.defineRootCommand(self: Identity, command: types.CommandInfo)
	for name in command.opts do
		if name == "help" or (self.globalOpts and self.globalOpts[name]) then
			error(`reserved option name: "{name}"`)
		end
	end

	self.rootCommand = command
	return self
end

function cli.run(self: Identity)
	local concatenated = table.concat(process.args, " ")
	local parserResult = parser(concatenated)
	local isHelp = false
	local subcommandHelp: string?

	if parserResult.options["help"] or ((#parserResult.arguments == 0) and not self.rootCommand) then
		isHelp = true

		if parserResult.arguments[1] then
			subcommandHelp = parserResult.arguments[1]
		end
	end

	if isHelp then
		local primary = self._palette.primary
		local secondary = self._palette.secondary
		local tertiary = self._palette.tertiary

		if self._metadata then
			print(`{primary(self._name)} {secondary(self._metadata.version)}`)
			print(`{tertiary(self._metadata.description)}`)
			print()
		end

		if not subcommandHelp then
			print(`{colorful.modifier.bold("Usage: ")}{self._name} [options] [commands]`)
			print()

			if self.subcommands then
				print(`{colorful.modifier.bold("Commands: ")}`)

				for name, subcommand in self.subcommands do
					print(`\t{colorful.modifier.bold(`{name}`)}: {tertiary(subcommand.description)}`)
				end
			end

			if self.globalOpts then
				print(`{colorful.modifier.bold("Options: ")}`)

				for name, globalOpt in self.globalOpts do
					print(`\t{colorful.modifier.bold(`--{name}`)}: {tertiary(globalOpt.description)}`)
				end
			end
		else
			assert(self.subcommands, "wtf")
			print(`{colorful.modifier.bold("Usage: ")}{self._name} {subcommandHelp} [options] [commands]`)
			print()

			local targetCommand = self.subcommands[subcommandHelp]

			print(`{colorful.modifier.bold("Parameters: ")}`)
			for _, subcommandParameter in targetCommand.parameters do
				print(
					`\t{colorful.modifier.bold(`{subcommandParameter.name}`)}: {tertiary(
						subcommandParameter.description
					)}`
				)
			end

			print(`{colorful.modifier.bold("Options: ")}`)
			for name, commandOpt in targetCommand.opts do
				print(`\t{colorful.modifier.bold(`--{name}`)}: {tertiary(commandOpt.description)}`)
			end
		end

		return
	end

	local options = parserResult.options

	if self.globalOpts then
		for name, globalOpt in self.globalOpts do
			if options[name] then
				globalOpt.runner()
			end
		end
	end

	if self.subcommands then
		local subcommandName = parserResult.arguments[1]
		local targetCommand

		for name, subcommand in self.subcommands do
			if name == subcommandName then
				targetCommand = subcommand
				break
			end
		end

		table.remove(parserResult.arguments, 1)

		assert(targetCommand, "wtf lol")

		handleCommand(targetCommand, parserResult.arguments, parserResult.options)
	else
		assert(self.rootCommand, "wtf")

		local command = self.rootCommand

		handleCommand(command, parserResult.arguments, parserResult.options)
	end
end

local exports = {
	types = {},
}

local exportedCommandFactory: types.DefineCommand
function exportedCommandFactory<_T, _K>(config, runner)
	local parameters = (config.parameters :: any) :: { [string]: types.Parameter<unknown> }
	local opts = (config.opts :: any) :: { [string]: types.Opt<unknown> }

	local result = {
		name = config.name,
		description = config.description,

		runner = runner,

		parameters = {},
		opts = {},
	}

	for name, parameter in parameters do
		result.parameters[parameter.position] = {
			name = name,
			description = parameter.description,
			type = parameter.type,
		}
	end

	for name, opt in opts do
		result.opts[name] = {
			name = name,
			description = opt.description,
			type = opt.type,
		}
	end

	return result
end

exports.command = exportedCommandFactory

function exports.parameter<T>(config: types.Parameter<T>): T
	return config :: any
end

function exports.opt<T>(config: types.Opt<T>): T?
	return config :: any
end

function exports.types.string(): types.TypeObject<string>
	return {
		name = "string",

		convert = function(value)
			return value
		end,

		validator = function(value)
			return typeof(value) == "string"
		end,
	}
end

function exports.types.number(): types.TypeObject<number>
	return {
		name = "number",

		convert = function(value)
			return tonumber(value) or error(`validated number couldn't be tonumber()'d`)
		end,

		validator = function(value)
			local asNumber = tonumber(value)

			return (asNumber ~= nil) and (asNumber == asNumber)
		end,
	}
end

function exports.types.boolean(): types.TypeObject<boolean>
	return {
		name = "boolean",

		convert = function(value)
			return value == "true"
		end,

		validator = function(value)
			return (value == "true") or (value == "false")
		end,
	}
end

function exports.types.none(): types.TypeObject<nil>
	return {
		name = "none",

		convert = function(_)
			return nil
		end,

		validator = function(value)
			return value == ""
		end,
	}
end

exports.cli = constructor

return exports