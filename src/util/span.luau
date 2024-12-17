--!strict
--!native
--!optimize 2

local file = require("@util/file")

--- A span stores the start and finish offset of a token or node
--- * x: start offset
--- * y: finish offset
--- * z: file id
export type Span = vector

local function create(start: number, finish: number, file_id: number): vector
    -- TODO: Replace with luau style constructor once lune updates
    return vector(start, finish, file_id) --vector.create(start, finish, file_id)
end

--- creates a span from a to b
local function merge(a: vector, b: vector): vector
    assert(a.z == b.z, "Spans must belong to the same file")
    return create(a.x, b.y, a.z)
end

local function length(span: vector): number
    return (span.y - span.x) + 1
end

local function value(span: vector): string
    local span_file = file.from_id(span.z)
    assert(span_file, "Span should belong to a file")

    local content = file.content(span_file)
    return buffer.readstring(content, span.x, length(span))
end

local function contains(span: vector, position: number): boolean
    return span.x <= position and span.y >= position
end

--- checks if two spans are intersecting, assumes `a.start` <= `b.start`
local function intersects(a: vector, b: vector): boolean
    return (a.y >= b.x)
end

return table.freeze({
    create = create,
    value = value,
    merge = merge,
    length = length,
    contains = contains,
    intersects = intersects
})