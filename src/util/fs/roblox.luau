local path = require("@util/path")
local file = require("@util/file")
local panic = require("@util/panic")
local result = require("@util/result")

local types = require("./types")

type Path = path.Path
type File = file.File
type Result<T, E> = result.Result<T, E>
type IOError = types.IOError

local function io_error(value: string): IOError
    return {
        kind = "io_error",
        value = value
    }
end

local function read_file(target: Path): Result<File, IOError>
    return panic("Unimplemented")
end

local function read_directory(target: Path): Result<{string}, IOError>
    return panic("Unimplemented")
end

local function write_file(target: Path, target_file: File): Result<nil, IOError>
    return panic("Unimplemented")
end

local function write_directory(target: Path): Result<nil, IOError>
    return panic("Unimplemented")
end

local function remove_file(target: Path): Result<nil, IOError>
    return panic("Unimplemented")
end


local function remove_directory(target: Path): Result<nil, IOError>
    return panic("Unimplemented")
end


local function is_file(target: Path): Result<boolean, IOError>
    return panic("Unimplemented")
end


local function is_directory(target: Path): Result<boolean, IOError>
    return panic("Unimplemented")
end

local function metadata(target: Path): Result<types.Metadata, IOError>
    return panic("Unimplemented")
end

local function move(from: Path, to: Path, options: types.WriteOptions?): Result<nil, IOError>
    return panic("Unimplemented")
end

local function copy(from: Path, to: Path, options: types.WriteOptions?): Result<nil, IOError>
    return panic("Unimplemented")
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
