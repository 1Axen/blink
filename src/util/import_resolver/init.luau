local md5 = require("@vendor/md5")

local file = require("@util/file")
local panic = require("@util/panic")
local option = require("@util/option")
local runtime = require("@util/runtime")

local aliases = require("./aliases")

local RUNTIME = runtime()

type File = file.File
type Option<T> = option.Option<T>

--- A map of md5 source hashes to files
local cached_files: {[string]: File} = {}
--- A map of `directory` to `aliases`
local cached_aliases: {[string]: aliases.Aliases} = {}

local function reuse_or_create_file(source: string): File
    local hash = md5(source)
    local existing = cached_files[hash]
    if existing then
        return existing
    end

    local new_file = file.from_source(source)
    cached_files[hash] = new_file

    return new_file
end

--- Resolves a file system import
local function resolve_fs_import(directory: string, path: string): Option<File>
    local fs = require("@lune/fs")

    local is_alias = (string.sub(path, 1 , 1) == "@")
    if is_alias then
        local aliases = cached_aliases[directory] or aliases.fs(directory)
        local slash_index = (string.find(path, "/", 1, true)) or 1

        local alias = string.sub(path, math.min(2, #path), slash_index)
        local replacement: string? = aliases[alias]
        if replacement == nil then
            return option.none()
        end

        path = `{replacement}{string.sub(path, slash_index, #path)}`
    end

    local final_path = `{directory}/{path}.blink`
    if fs.isFile(final_path) == false then
        return option.none()
    end

    local io_success, source = pcall(function()
        return fs.readFile(final_path)
    end)

    if io_success == false then
        return panic(`IOError while trying to read import "{final_path}": {source}`)
    end

    local resolved_file = reuse_or_create_file(source)
    return option.some(resolved_file)
end

--- Resolves a ROBLOX import
--- Unimplemented for now
local function resolve_roblox_import(directory: string, path: string): Option<File>
    error("Unimplemented")
end

--- Takes in a starting `directory` and import `path`, and returns a `file?`
local function resolve_import(directory: string, path: string): Option<File>
    if RUNTIME == "Lune" then
        return resolve_fs_import(directory, path)
    elseif RUNTIME == "ROBLOX" then
        return resolve_roblox_import(directory, path)
    end

    return panic(`Unhandled runtime "{RUNTIME}"`)
end

return table.freeze({
    resolve = resolve_import
})