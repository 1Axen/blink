local colorful = require("@vendor/colorful")

local color = colorful.color

local OPEN = colorful.color.gray("[")
local CLOSE = colorful.color.gray("]")

local INFO_PREFIX = `{OPEN}{color.yellow("Info")}{CLOSE}`
local ERROR_PREFIX = `{OPEN}{color.red("Error")}{CLOSE}`
local VERBOSE_PREFIX = `{OPEN}{color.magenta("Verbose")}{CLOSE}`

local function print_info(...)
	local args = { ... }
	table.insert(args, 1, INFO_PREFIX)

	local text = table.concat(args, " ")
	print(text)
end

local function print_error(...)
	local args = { ... }
	table.insert(args, 1, ERROR_PREFIX)

	local text = table.concat(args, " ")
	print(colorful.modifier.bold(text))
end

local function print_verbose(...)
	local args = { ... }
	table.insert(args, 1, VERBOSE_PREFIX)

	local text = table.concat(args, " ")
	print(colorful.modifier.dim(text))
end

return table.freeze({
	info = print_info,
	error = print_error,
	verbose = print_verbose,
})
