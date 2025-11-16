local fs = require("@lute/fs")

local file = require("@util/file")
local panic = require("@util/panic")
local path = require("@util/path")
local result = require("@util/result")

local types = require("./types")

type Path = path.Path
type File = file.File
type Result<T, E> = result.Result<T, E>
type IOError = types.IOError

local function read_file(target: Path): Result<File, IOError>
	local path_str = path.to_string(target)
	local fs_success, fs_return = pcall(function()
		return fs.readfiletostring(path_str)
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

local function read_directory(target: Path): Result<{ string }, IOError>
	local path_str = path.to_string(target)
	local fs_success, fs_return = pcall(function()
		return fs.listdir(path_str)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	local directory_entries = table.create(#fs_return) :: { string }
	for index, entry in fs_return do
		directory_entries[index] = entry.name
	end

	return result.ok(directory_entries)
end

local function write_file(target: Path, target_file: File): Result<nil, IOError>
	local path_str = path.to_string(target)
	local contents = file.as_string(target_file)
	local fs_success = pcall(function()
		fs.writestringtofile(path_str, contents)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(nil)
end

local function write_directory(target: Path): Result<nil, IOError>
	local path_str = path.to_string(target)
	local fs_success = pcall(function()
		fs.mkdir(path_str)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(nil)
end

local function remove_file(target: Path): Result<nil, IOError>
	local path_str = path.to_string(target)
	local fs_success = pcall(function()
		fs.remove(path_str)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(nil)
end

local function remove_directory(target: Path): Result<nil, IOError>
	local path_str = path.to_string(target)
	local fs_success = pcall(function()
		fs.rmdir(path_str)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(nil)
end

local function is_file(target: Path): Result<boolean, IOError>
	local path_str = path.to_string(target)
	local fs_success, fs_return = pcall(function()
		return fs.type(path_str) == "file"
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(fs_return)
end

local function is_directory(target: Path): Result<boolean, IOError>
	local path_str = path.to_string(target)
	local fs_success, fs_return = pcall(function()
		return fs.type(path_str) == "dir"
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok(fs_return)
end

local function metadata(target: Path): Result<types.Metadata, IOError>
	local path_str = path.to_string(target)
	if fs.exists(path_str) == false then
		return result.ok({
			exists = false,
		} :: types.Metadata)
	end

	local fs_success, fs_metadata = pcall(function()
		return fs.stat(path_str)
	end)

	if fs_success == false then
		return result.err("IOError" :: IOError)
	end

	return result.ok({
		exists = true,
		kind = fs_metadata.type,
		created_at = fs_metadata.created,
		modified_at = fs_metadata.modified,
		accessed_at = fs_metadata.accessed,
		permissions = {
			read_only = fs_metadata.permissions.readonly,
		},
	} :: types.Metadata)
end

local function move(from: Path, to: Path, options: types.WriteOptions?): Result<nil, IOError>
	local from_str = path.to_string(from)
	local to_str = path.to_string(to)

	local fs_success, _ = pcall(function()
		fs.copy(from_str, to_str, options)
		fs.remove(from_str)
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

	local fs_success, _ = pcall(function()
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
	copy = copy,
})
