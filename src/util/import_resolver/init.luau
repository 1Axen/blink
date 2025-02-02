local fs = require("@util/fs")
local file = require("@util/file")
local path = require("@util/path")
local panic = require("@util/panic")
local result = require("@util/result")
local runtime = require("@util/runtime")

local aliases = require("./aliases")

local RUNTIME = runtime()

type File = file.File
type Path = path.Path
type Result<T, E> = result.Result<T, E>

type UnknownAlias = "UnknownAlias"
type UnknownImport = "UnknownImport"

type ImportError = 
    | fs.IOError
    | UnknownAlias
    | UnknownImport

export type Import = {
    path: Path,
    file: File
}

type ImportResult = Result<Import, ImportError>

--- A map of `directory` to `aliases`
local cached_aliases: {[string]: aliases.Aliases} = {}

--- Resolves a file system import
local function resolve_fs_import(import_path: Path): ImportResult
    local directory = path.strip_file_name(import_path)
    local directory_string = path.to_string(directory)

    if path.starts_with(import_path, "@") then
        local aliases = cached_aliases[directory_string] or aliases.fs(directory)

        local slice: string
        import_path, slice = path.pop(import_path, 1)

        local alias = slice :: string
        alias = string.sub(alias, 2, #alias)

        local replacement: Path? = aliases[alias]
        if replacement == nil then
            return result.err("UnknownAlias" :: UnknownAlias)
        end

        import_path = path.join(replacement, import_path)
    else
        import_path = path.join(directory, import_path)
    end

    if fs.is_file(import_path).value ~= true then
        return result.err("UnknownImport" :: UnknownImport)
    end

    local fs_result = fs.read_file(import_path)
    if fs_result.error then
        return fs_result :: result.Error<fs.IOError>
    end

    return result.ok({
        path = import_path,
        file = fs_result.value
    })
end

--- Resolves a ROBLOX import
--- Unimplemented for now
local function resolve_roblox_import(import_path: Path): ImportResult
    error("Unimplemented")
end

--- Takes in a starting `directory` and import `path`, and returns a `file?`
local function resolve_import(import_path: Path): ImportResult
    if RUNTIME == "ROBLOX" then
        return resolve_roblox_import(import_path)
    end

    return resolve_fs_import(import_path)
end

return table.freeze({
    resolve = resolve_import
})