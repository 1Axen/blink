local fs = require("@util/fs")
local luaurc = require("./luaurc")
local path = require("@util/path")
local result = require("@util/result")

type Path = path.Path
type Result<T, E> = result.Result<T, E>
export type Aliases = { [string]: Path }

--stylua: ignore
type ParseError = 
	| fs.IOError
    | luaurc.ParseError

local function aliases_from_path(path: Path): Result<Aliases, ParseError>
	local read_result = fs.read_string_from_file(path)
	if read_result.ok == false then
		return read_result
	end

	local luaurc_result = luaurc.parse(read_result.value)
	if luaurc_result.ok == false then
		return luaurc_result
	end

	local luaurc = luaurc_result.value
	return result.ok(luaurc.aliases or {})
end

--- Unimplemented for now
local function collect_roblox_aliases(): Aliases
	return {}
end

--- Implemented according to https://github.com/luau-lang/rfcs/blob/master/docs/require-by-string-aliases.md
local function collect_fs_aliases(directory: Path): Aliases
	local collected_aliases: Aliases = {}
	local current_directory: Path? = directory

	local function insert_unique_aliases(luaurc_directory: Path, aliases: Aliases)
		for alias, luaurc_relative_path in aliases do
			if collected_aliases[alias] then
				continue
			end

			local file_relative_path = path.join(luaurc_directory, luaurc_relative_path)
			collected_aliases[alias] = file_relative_path
		end
	end

	while current_directory do
		if not fs.is_directory(current_directory) then
			break
		end

		local luaurc_path = path.append_file_name(current_directory, "", "luaurc")
		if fs.is_file(luaurc_path) then
			local aliases_result = aliases_from_path(luaurc_path)
			if aliases_result.ok then
				insert_unique_aliases(current_directory, aliases_result.value)
			else
				local err = aliases_result.error
				print(`Unable to retrieve aliases from "{path.to_string(luaurc_path)}": {err.kind} {err.message}`)
			end
		end

		current_directory = path.parent(current_directory)
	end

	return collected_aliases
end

return table.freeze({
	collect_fs = collect_fs_aliases,
	cpllect_roblox = collect_roblox_aliases,
})
