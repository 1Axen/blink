--!strict
--!native
--!optimize 2

local file = require("@util/file")

--- A span stores the start and finish offset of a token or node
--- * x: start offset
--- * y: finish offset
--- * z: file id
-- TODO: Replace with vector
export type Span = {x: number, y: number, z: number}

local function create(start: number, finish: number, file_id: number): Span
    return {x = start, y = finish, z = file_id}
end

--- creates a span from a to b
local function merge(a: Span, b: Span): Span
    assert(a.z == b.z, "Spans must belong to the same file")
    return create(a.x, b.y, a.z)
end

local function length(span: Span): number
    return (span.y - span.x) + 1
end

local function value(span: Span): string
    local span_file = file.from_id(span.z)
    assert(span_file, "Span should belong to a file")

    local content = file.content(span_file)
    return buffer.readstring(content, span.x, length(span))
end

local function contains(span: Span, position: number): boolean
    return span.x <= position and span.y >= position
end

--- checks if two spans are intersecting, assumes `a.start` <= `b.start`
local function intersects(a: Span, b: Span): boolean
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