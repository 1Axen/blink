local ast = require("@ast")
local compilation = require("@config/compilation")
local options = require("@config/options")
local report = require("@compiler/report")
local types = require("@hir/types")

type Hir = types.Hir
type FileOptions = options.FileOptions
type SeenOptions = { [string]: ast.StatOption }

local function record_option(file_options: FileOptions, seen_options: SeenOptions, stat: ast.StatOption): never?
	local name = stat.name.value
	local previous = seen_options[name]
	if previous then
		return report.duplicate_option(stat, previous)
	end

	local option_config = (options :: { [string]: options.Option? })[name]
	if option_config == nil then
		return report.unknown_option(stat)
	end

	local value_expr = stat.value
	if value_expr.kind ~= option_config.kind then
		return report.invalid_option_type(stat, option_config.kind)
	end

	local value = value_expr.value
	if option_config.values and table.find(option_config.values, value) == nil then
		return report.invalid_option_value(stat, option_config.values)
	end

	seen_options[name] = stat;
	(file_options :: any)[name] = value

	return nil
end

local function populate_options(hir: Hir, files: compilation.Files)
	for file_id, file_ast in files.ast_map do
		local file_options: FileOptions = {}
		local seen_options: SeenOptions = {}

		for _, stat in file_ast.body.statements do
			if stat.kind == "option" then
				record_option(file_options, seen_options, stat)
			end
		end

		hir.options[file_id] = file_options
	end
end

return populate_options
