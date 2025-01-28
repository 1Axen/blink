local fs = require("@lune/fs")

local path = require("@util/path")
local file = require("@util/file")
local panic = require("@util/panic")
local result = require("@util/result")

local types = require("./types")

type Path = path.Path
type File = file.File
type Result<T, E> = result.Result<T, E>
type IOError = types.IOError

local function read_file(target: Path): Result<File, IOError>
    local path_str = path.to_string(target)
    local fs_success, fs_return = pcall(function()
        return fs.readFile(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    local file_name = path.file_name(target)
    if file_name == nil then
        return panic(`Unable to parse file name from path "{path_str}"`)
    end

    return result.ok(file.from_source(file_name, fs_return))
end

local function read_directory(target: Path): Result<{string}, IOError>
    local path_str = path.to_string(target)
    local fs_success, fs_return = pcall(function()
        return fs.readDir(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(fs_return)
end

local function write_file(target: Path, target_file: File): Result<nil, IOError>
    local path_str = path.to_string(target)
    local contents = file.as_string(target_file)
    local fs_success = pcall(function()
        fs.writeFile(path_str, contents)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end

local function write_directory(target: Path): Result<nil, IOError>
    local path_str = path.to_string(target)
    local fs_success = pcall(function()
        fs.writeDir(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end

local function remove_file(target: Path): Result<nil, IOError>
    local path_str = path.to_string(target)
    local fs_success = pcall(function()
        fs.readFile(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end


local function remove_directory(target: Path): Result<nil, IOError>
    local path_str = path.to_string(target)
    local fs_success = pcall(function()
        fs.removeDir(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end


local function is_file(target: Path): Result<boolean, IOError>
    local path_str = path.to_string(target)
    local fs_success, fs_return = pcall(function()
        return fs.isFile(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(fs_return)
end


local function is_directory(target: Path): Result<boolean, IOError>
    local path_str = path.to_string(target)
    local fs_success, fs_return = pcall(function()
        return fs.isDir(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(fs_return)
end

local function metadata(target: Path): Result<types.Metadata, IOError>
    local path_str = path.to_string(target)
    local fs_success, fs_metadata = pcall(function()
        return fs.metadata(path_str)
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    if fs_metadata.exists then
        local created_at = fs_metadata.createdAt and fs_metadata.createdAt.unixTimestamp or nil
        local modified_at = fs_metadata.modifiedAt and fs_metadata.modifiedAt.unixTimestamp or nil
        local accessed_at = fs_metadata.accessedAt and fs_metadata.accessedAt.unixTimestamp or nil

        return result.ok({
            exists = true,
            kind = fs_metadata.kind,
            created_at = created_at,
            modified_at = modified_at,
            accessed_at = accessed_at,
            permissions = {
                read_only = fs_metadata.permissions.readOnly
            }
        } :: types.Metadata)
    end

    return result.ok({
        exists = false
    } :: types.Metadata)
end

local function move(from: Path, to: Path, options: types.WriteOptions?): Result<nil, IOError>
    local from_str = path.to_string(from)
    local to_str = path.to_string(to)

    local fs_success, fs_error = pcall(function()
        fs.move(from_str, to_str, options)
        return nil
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end

local function copy(from: Path, to: Path, options: types.WriteOptions?): Result<nil, IOError>
    local from_str = path.to_string(from)
    local to_str = path.to_string(to)

    local fs_success, fs_error = pcall(function()
        fs.copy(from_str, to_str, options)
        return nil
    end)

    if fs_success == false then
        return result.err("IOError" :: IOError)
    end

    return result.ok(nil)
end

return table.freeze({
    read_file = read_file,
    read_directory = read_directory,

    write_file = write_file,
    write_directory = write_directory,

    remove_file = remove_file,
    remove_directory = remove_directory,

    is_file = is_file,
    is_directory = is_directory,

    metadata = metadata,

    move = move,
    copy = copy
})
