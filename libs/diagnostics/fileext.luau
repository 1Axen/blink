local assert_panic = require("@util/assert_panic")
local file = require("@util/file")
local panic = require("@util/panic")
local span = require("@util/span")

type File = file.File
type Line = file.Line
type Span = span.Span

export type Point = {
	-- index into a file's lines
	read line: number,
	-- byte offset within the line
	read offset: number,
}

export type Segment = {
	read start: Point,
	read finish: Point,
}

local function binary_search_with_comparator<T, V>(vec: { T }, target: V, compare: (value: T, target: V) -> number): number?
	local low, high = 1, #vec
	while low <= high do
		local mid = bit32.rshift(low + high, 1)
		local diff = compare(vec[mid], target)
		if diff == 0 then
			return mid
		elseif diff < 0 then
			low = mid + 1
		else
			high = mid - 1
		end
	end

	return nil
end

local function line_from_offset(offset_file: File, byte_offset: number): Line?
	local lines = file.as_lines(offset_file)
	local index = binary_search_with_comparator(lines, byte_offset, function(line: Line, target: number): number
		if line.x <= target and target <= line.y then
			return 0
		end

		return line.x - target
	end)

	if index == nil then
		return nil
	end

	return lines[index]
end

local function point_from_offset(offset_file: File, byte_offset: number): Point
	local line = line_from_offset(offset_file, byte_offset)
	if line == nil then
		return panic(`Byte offset {byte_offset} is greater than the length of the file {file.length(offset_file)}`)
	end

	return table.freeze({
		line = line.z,
		offset = byte_offset - line.x,
	})
end

local function segment_from_span(span: Span): Segment
	local span_file = assert_panic(file.from_id(span.z), "expected span to belong to a file")
	return table.freeze({
		start = point_from_offset(span_file, span.x),
		finish = point_from_offset(span_file, span.y),
	})
end

local function lines_of_segment(segment_file: File, segment: Segment): { Line }
	local lines = file.as_lines(segment_file)
	local segment_lines = table.create(segment.finish.line - segment.start.line) :: { Line }
	for index = segment.start.line, segment.finish.line do
		table.insert(segment_lines, lines[index])
	end
	return segment_lines
end

return table.freeze({
	line_from_offset = line_from_offset,
	point_from_offset = point_from_offset,
	segment_from_span = segment_from_span,
	lines_of_segment = lines_of_segment,
})
