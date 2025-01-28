local md5 = require("@vendor/md5")
local option = require("@util/option")

local EMPTY_BUFFER = buffer.create(0)

export type File = {
    read id: number,
    read name: string,
    read buffer: buffer,
    lines: {string}?,
}

local files: {File} = {}
local hash_to_file: {[string]: File} = {}

--- creates and returns an empty file
local function create(name: string, buffer: buffer?): File
    local file: File = {
        id = #files,
        name = name,
        lines = nil :: any,
        buffer = buffer or EMPTY_BUFFER,
    }

    files[file.id] = file
    return file
end

--- returns the `file` corresponding to `id`
local function from_id(id: number): option.Option<File>
    local file = files[id]
    if file == nil then
        return option.none()
    end

    return option.some(file)
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
local function as_lines(self: File): {string}
    -- TODO: Implement
    return {}
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
