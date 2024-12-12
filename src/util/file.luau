local DEFAULT_NAME = "file.blink"

export type File = {
    id: number,
    name: string?,
    lines: {string}?,
    content: buffer,
}

local files: {File} = {}

--- creates an empty `file`
local function create(): File
    local index = (#files + 1)
    local file: File = {
        id = index,
        content = buffer.create(1)
    }

    table.insert(files, file)
    return file
end

--- returns the `file` corresponding to `id`
--- returns `nil` of no such file exists
local function from_id(id: number): File
    return files[id]
end

--- creates a `file` and sets it's `content` to `source`
local function from_source(source: string): File
    local file = create()
    file.content = buffer.fromstring(source)
    return file
end

--- returns the `id` of the `file`
local function id(file: File): number
    return file.id
end

--- returns the `name` of the `file`
--- defaults to `file.blink` if no `name` is set
local function name(file: File): string
    return file.name or DEFAULT_NAME
end

--- returns the length of the `file's` `content` buffer
local function length(file: File): number
    return buffer.len(file.content)
end

--- returns the `content` buffer of `file`
local function content(file: File): buffer
    return file.content
end

--- returns an array of lines from the `content` of the `file`
--- this method can be expensive for large files thus subsequent calls are cached
local function lines(file: File): {string}
    -- TODO: Implement
    return {}
end

return table.freeze({
    create = create,

    from_id = from_id,
    from_source = from_source,

    id = id,
    lines = lines,
    length = length,
    content = content,
})
