local fs = require("@lute/fs")

local file = require("@util/file")
local panic = require("@util/panic")
local path = require("@util/path")
local result = require("@util/result")

local types = require("./types")

type Path = path.Path
type File = file.File
type Result<T = nil> = types.Result<T>

local io_error = types.io_error

local function read_file(target: Path): Result<File>
	local path_str = path.to_string(target)
	local success, contents = pcall(function()
		return fs.readfiletostring(path_str)
	end)

	if success == false then
		return io_error(contents)
	end

	local file_name = path.file_name(target)
	if file_name == nil then
		return panic(`Unable to parse file name from path "{path_str}"`)
	end

	return result.ok(file.from_source(file_name, contents))
end

local function read_directory(target: Path): Result<{ string }>
	local path_str = path.to_string(target)
	local success, entries = pcall(function()
		return fs.listdir(path_str)
	end)

	if success == false then
		return io_error(entries :: any)
	end

	local directory_entries = table.create(#entries) :: { string }
	for index, entry in entries do
		directory_entries[index] = entry.name
	end

	return result.ok(directory_entries)
end

local function write_file(target: Path, target_file: File): Result
	local path_str = path.to_string(target)
	local contents = file.as_string(target_file)
	local success, err = pcall(function()
		fs.writestringtofile(path_str, contents)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

local function write_directory(target: Path): Result
	local path_str = path.to_string(target)
	local success, err = pcall(function()
		fs.mkdir(path_str)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

local function remove_file(target: Path): Result
	local path_str = path.to_string(target)
	local success, err = pcall(function()
		fs.remove(path_str)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

local function remove_directory(target: Path): Result
	local path_str = path.to_string(target)
	local success, err = pcall(function()
		fs.rmdir(path_str)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

local function is_file(target: Path): boolean
	local path_str = path.to_string(target)
	local success, type_result = pcall(function()
		return fs.type(path_str) == "file"
	end)

	return success and type_result
end

local function is_directory(target: Path): boolean
	local path_str = path.to_string(target)
	local success, type_result = pcall(function()
		return fs.type(path_str) == "dir"
	end)

	return success and type_result
end

local function metadata(target: Path): Result<types.Metadata>
	local path_str = path.to_string(target)
	local success, raw_metadata = pcall(function()
		return fs.stat(path_str)
	end)

	if success == false then
		return io_error(raw_metadata :: any)
	end

	local metadata: types.Metadata = {
		kind = raw_metadata.type,
		created_at = raw_metadata.created,
		modified_at = raw_metadata.modified,
		accessed_at = raw_metadata.accessed,
		permissions = {
			read_only = raw_metadata.permissions.readonly,
		},
	}

	return result.ok(metadata)
end

local function move(from: Path, to: Path, options: types.WriteOptions?): Result
	local from_str = path.to_string(from)
	local to_str = path.to_string(to)

	local success, err = pcall(function()
		fs.copy(from_str, to_str, options)
		fs.remove(from_str)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

local function copy(from: Path, to: Path, options: types.WriteOptions?): Result
	local from_str = path.to_string(from)
	local to_str = path.to_string(to)

	local success, err = pcall(function()
		fs.copy(from_str, to_str, options)
		return nil
	end)

	if success == false then
		return io_error(err :: any)
	end

	return result.ok()
end

return table.freeze({
	read_file = read_file,
	read_directory = read_directory,

	write_file = write_file,
	write_directory = write_directory,

	remove_file = remove_file,
	remove_directory = remove_directory,

	exists = exists,
	is_file = is_file,
	is_directory = is_directory,

	metadata = metadata,

	move = move,
	copy = copy,
})
