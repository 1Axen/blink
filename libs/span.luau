--!strict
--!native
--!optimize 2

local file = require("@util/file")
local panic = require("./panic")

--- A span stores the start and finish offset of a token or node
--- * x: start offset
--- * y: finish offset
--- * z: file id
export type Span = vector

local function create(start: number, finish: number, file_id: number): vector
	return vector.create(start, finish, file_id)
end

--- creates a span from a to b
local function merge(a: vector, b: vector): Span
	if a.z ~= b.z then
		return panic("Spans don't belong to the same file")
	end
	return create(a.x, b.y, a.z)
end

local function length(span: vector): number
	return (span.y - span.x) + 1
end

local function as_string(span: vector): string
	local source = file.from_id(span.z)
	if source == nil then
		return panic("Span doesn't belong to any file")
	end
	return buffer.readstring(source.buffer, span.x, length(span))
end

local function contains(span: vector, position: number): boolean
	return span.x <= position and span.y >= position
end

--- checks if two spans are intersecting, assumes `a.start` <= `b.start`
local function intersects(a: vector, b: vector): boolean
	if a.z ~= b.z then
		return panic("Spans don't belong to the same file")
	end
	return (a.y >= b.x)
end

return table.freeze({
	create = create,
	value = as_string,
	merge = merge,
	length = length,
	contains = contains,
	intersects = intersects,
})
