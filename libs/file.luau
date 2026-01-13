local md5 = require("@vendor/md5")

local EMPTY_BUFFER = buffer.create(0)

--- * `.x` start byte offset
--- * `.y` finish byte offset
--- * `.z` line number
export type Line = vector
export type Lines = { Line }

export type File = {
	read id: number,
	read name: string,
	read buffer: buffer,
	lines: Lines?,
}

local next_id = 0
local files: { File } = {}

local hash_to_file: { [string]: File } = {}

--- creates and returns an empty file
local function create(name: string, buffer: buffer?): File
	local file: File = {
		id = next_id,
		name = name,
		lines = nil :: any,
		buffer = buffer or EMPTY_BUFFER,
	}

	next_id += 1
	files[file.id] = file

	return file
end

--- returns the `file` corresponding to `id`
local function from_id(id: number): File?
	return files[id]
end

--- creates and returns a new file from the source contents
local function from_source(name: string, source: string): File
	local hash = md5(source)

	-- check if the file was already created
	local existing = hash_to_file[hash]
	if existing then
		return existing
	end

	-- create a new file & cache it by its md5 hash
	local new_file = create(name, buffer.fromstring(source))
	hash_to_file[hash] = new_file

	return new_file
end

--- returns the *length* of the file's internal buffer
local function length(self: File): number
	return buffer.len(self.buffer)
end

--- returns the contents of the file as an array of `\n` terminated lines.
local function as_lines(self: File): Lines
	if self.lines then
		return self.lines
	end

	local lines = table.create(64) :: Lines
	local contents = self.buffer
	local file_length = length(self)

	local line_index = 0
	local line_start = 0
	local was_newline = false

	for offset = 0, file_length - 1 do
		if was_newline then
			line_index += 1
			lines[line_index] = vector.create(line_start, offset - 1, line_index)
			line_start = offset
		end

		local byte = buffer.readu8(contents, offset)
		was_newline = byte == string.byte("\n")
	end

	-- add remainder as a line
	table.insert(lines, vector.create(line_start, file_length, line_index + 1))

	self.lines = lines
	return lines
end

--- returns the contents of the file
local function as_string(self: File): string
	return buffer.tostring(self.buffer)
end

return table.freeze({
	from_id = from_id,
	from_source = from_source,

	length = length,
	as_lines = as_lines,
	as_string = as_string,
})
