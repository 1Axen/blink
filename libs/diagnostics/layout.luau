local fileext = require("./fileext")
local types = require("./types")

type Label = types.Label
type Diagnostic = types.Diagnostic
type Segment = fileext.Segment

export type InlineLayout = {
	--- offset in the line the label should be attached to
	read offset: number,
	read segment: Segment,
	read label: Label,
}

export type MultilineLayout = {
	--- Unique sorted index within its file
	file_index: number,
	--- Unique sorted index within its line, used when a line is covered by multiple spans
	line_index: number,
	read segment: Segment,
	read label: Label,
}

export type LineLayout = {
	read index: number,
	read inlines: { InlineLayout },
	read multilines: { MultilineLayout },
}

export type FileLayout = {
	read lines: { LineLayout },
	read max_multiline_nesting: number,
}

local function create_file_layout(labels: { Label }): FileLayout
	local inlines = table.create(#labels) :: { InlineLayout }
	local multilines = table.create(#labels) :: { MultilineLayout }

	for _, label in labels do
		local segment = fileext.segment_from_span(label.span)
		if segment.start.line == segment.finish.line then
			table.insert(inlines, {
				offset = (segment.start.offset + segment.finish.offset) // 2,
				segment = segment,
				label = label,
			})
		else
			table.insert(multilines, {
				file_index = 0,
				line_index = -1,
				segment = segment,
				label = label,
			})
		end
	end

	table.sort(multilines, function(a: { segment: Segment }, b: { segment: Segment })
		local a_lines = (a.segment.finish.line - a.segment.start.line)
		local b_lines = (b.segment.finish.line - b.segment.start.line)
		return a_lines > b_lines
	end)

	for index, multiline in multilines do
		multiline.file_index = index
	end

	local line_indices: { [number]: true } = {}
	for _, inline in inlines do
		line_indices[inline.segment.start.line] = true
	end
	for _, multiline in multilines do
		for line_index = multiline.segment.start.line, multiline.segment.finish.line do
			line_indices[line_index] = true
		end
	end

	local slots: { [number]: number? } = {}
	local lines = table.create(#labels) :: { LineLayout }
	local max_multiline_nesting = 0

	for line in line_indices do
		local line_inlines = {}
		for _, inline in inlines do
			if inline.segment.start.line == line then
				table.insert(line_inlines, inline)
			end
		end

		table.sort(line_inlines, function(a: InlineLayout, b: InlineLayout)
			return a.offset < b.offset
		end)

		local line_multilines = {}
		for _, multiline in multilines do
			local segment = multiline.segment
			if segment.start.line > line or segment.finish.line < line then
				continue
			end

			if multiline.line_index == -1 then
				local line_index = slots[multiline.file_index]
				if not line_index then
					local search_index = 0
					while true do
						search_index += 1

						local file_index = slots[search_index]
						if file_index and multilines[file_index].segment.finish.line < line then
							slots[search_index] = nil
						end

						if slots[search_index] == nil then
							slots[search_index] = multiline.file_index
							line_index = search_index
							break
						end
					end
				end
				multiline.line_index = assert(line_index, "unreachable")
			end

			table.insert(line_multilines, multiline)
		end

		table.sort(line_multilines, function(a: MultilineLayout, b: MultilineLayout)
			return a.line_index < b.line_index
		end)

		max_multiline_nesting = math.max(max_multiline_nesting, #line_multilines)
		table.insert(lines, {
			index = line,
			inlines = line_inlines,
			multilines = line_multilines,
		})
	end

	table.sort(lines, function(a: LineLayout, b: LineLayout)
		return a.index < b.index
	end)

	return table.freeze({
		lines = lines,
		max_multiline_nesting = max_multiline_nesting,
	})
end

return table.freeze({
	from_labels = create_file_layout,
})
