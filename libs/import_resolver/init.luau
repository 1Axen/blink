local file = require("@util/file")
local fs = require("@util/fs")
local path = require("@util/path")
local result = require("@util/result")
local runtime = require("@util/runtime")

local aliases = require("@self/aliases")

local RUNTIME = runtime()
local EXTENSIONS = {
	"blink",
	--- For luau API support
	-- "luau",
	-- "lua"
}

type File = file.File
type Path = path.Path
type Result<T, E> = result.Result<T, E>

export type UnknownAlias = {
	kind: "UnknownAlias",
	alias: string,
}

export type UnknownImport = {
	kind: "UnknownImport",
	path: Path,
}

--stylua: ignore
export type ImportError = 
	| fs.IOError
    | UnknownAlias
    | UnknownImport

export type Import = {
	path: Path,
	file: File,
}

type ImportResult = Result<Import, ImportError>

--- A map of `directory` to `aliases`
local cached_aliases: { [string]: aliases.Aliases? } = {}

--- Resolves a file system import
local function resolve_fs_import(directory: Path, import: Path): ImportResult
	local directory_string = path.to_string(directory)

	if path.starts_with(import, "@") then
		local available_aliases = cached_aliases[directory_string]
		if available_aliases == nil then
			available_aliases = aliases.collect_fs(directory)
			cached_aliases[directory_string] = available_aliases
		end

		-- TODO: remove assert once type state works
		assert(available_aliases)

		-- pop the alias from the path
		local slice: string
		import, slice = path.pop(import, 1)

		local alias = slice :: string
		alias = string.sub(alias, 2, #alias)

		local replacement: Path? = available_aliases[alias]
		if replacement == nil then
			return result.err({
				kind = "UnknownAlias" :: "UnknownAlias",
				alias = alias,
			})
		end

		-- replace it with the aliased path
		import = path.join(replacement, import)
	else
		import = path.join(directory, import)
	end

	local import_stem = path.file_stem(import)
	if import_stem then
		for _, extension in EXTENSIONS do
			local final_import = path.with_file_name(import, import_stem, extension)
			if not fs.is_file(final_import) then
				continue
			end

			local read_result = fs.read_file(final_import)
			if read_result.ok == false then
				return read_result
			end

			return result.ok({
				path = final_import,
				file = read_result.value,
			})
		end
	end

	return result.err({
		kind = "UnknownImport" :: "UnknownImport",
		path = import,
	})
end

--- Resolves a ROBLOX import
--- Unimplemented for now
local function resolve_roblox_import(directory: Path, import: Path): ImportResult
	error("Unimplemented")
end

--- Takes in a starting `directory` and import `path`, and returns a `file?`
local function resolve_import(directory: Path, import: Path): ImportResult
	if RUNTIME == "ROBLOX" then
		return resolve_roblox_import(directory, import)
	end

	return resolve_fs_import(directory, import)
end

return table.freeze({
	resolve = resolve_import,
})
