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

--- A map of `directory` to `aliases`
local cached_aliases: {[string]: aliases.Aliases} = {}

--- Resolves a file system import
local function resolve_fs_import(directory_path: Path, import_path: Path): Result<File, ImportError>
    if path.starts_with(import_path, "@") then
        local directory_string = path.to_string(directory_path)
        local aliases = cached_aliases[directory_string] or aliases.fs(directory_path)

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
        import_path = path.join(directory_path, import_path)
    end

    if fs.is_file(import_path).value ~= true then
        return result.err("UnknownImport" :: UnknownImport)
    end

    return fs.read_file(import_path)
end

--- Resolves a ROBLOX import
--- Unimplemented for now
local function resolve_roblox_import(directory_path, import_path: Path): Result<File, ImportError>
    error("Unimplemented")
end

--- Takes in a starting `directory` and import `path`, and returns a `file?`
local function resolve_import(directory_path: Path, import_path: Path): Result<File, ImportError>
    if RUNTIME == "Lune" then
        return resolve_fs_import(directory_path, import_path)
    elseif RUNTIME == "ROBLOX" then
        return resolve_roblox_import(directory_path, import_path)
    end

    return panic(`Unhandled runtime "{RUNTIME}"`)
end

return table.freeze({
    resolve = resolve_import
})