local assert_panic = require("@util/assert_panic")
local file = require("@util/file")
local layout = require("./layout")
local panic = require("@util/panic")
local string_builder = require("@util/string_builder")
local style = require("@util/style")
local types = require("./types")

type File = file.File
type Style = style.Styler
type StringBuilder = string_builder.StringBuilder

local DIM = style.modifer.dim
local NOOP_STYLE: Style = function(...)
	return ...
end

local KIND_STYLE: { [types.DiagnosticKind]: Style } = {
	Error = style.color.red,
	Warning = style.color.yellow,
	Info = style.color.cyan,
}

local CHAR_SET = table.freeze({
	margin_bar = "│",
	margin_bar_skip = "┆",
	margin_h = "─",
	margin_top_left = "╭",
	margin_top_right = "╮",
	margin_bottom_right = "╯",
	label_v = "│",
	label_h = "─",
	label_top_left = "╭",
	label_bottom_left = "╰",
	arrow_right = "▶",
	arrow_underline = "─",
	arrow_underconnect = "┬",
	cross = "┼",
	right_cross = "├",
})

local function overlap(content: string, padding: string, raw_content: string?): string
	local length = assert_panic(utf8.len(raw_content or content), "Invalid UTF-8 sequence")
	return `{content}{string.sub(padding, length + 1)}`
end

local function canonicalize(char: string): string
	if char == "\n" or char == "\r" then
		return ""
	elseif char == "\t" then
		return "    "
	end

	return char
end

local function append_source(
	stream: StringBuilder,
	source: string,
	style_at: (char: string, first: number, last: number) -> string
)
	for offset, codepoint in utf8.codes(source) do
		local char = utf8.char(codepoint)
		local bytes = #char

		local first = offset - 1
		local last = (first + bytes) - 1

		local canonicalized = canonicalize(char)
		local styled = style_at(canonicalized, first, last)
		stream:append(styled)
	end
end

local function append_underlines(
	stream: StringBuilder,
	source: string,
	underline_at: (first: number, last: number) -> string
)
	for offset, codepoint in utf8.codes(source) do
		local char = utf8.char(codepoint)
		local bytes = #char

		local first = offset - 1
		local last = (first + bytes) - 1

		local canonicalized = canonicalize(char)
		local columns = assert_panic(utf8.len(canonicalized), "Invalid UTF-8 sequence")
		local underline = underline_at(first, last)
		for _ = 1, columns do
			stream:append(underline)
		end
	end
end

local function render(diagnostic: types.Diagnostic): string
	local stream = string_builder.create({})

	-- header
	stream:append(KIND_STYLE[diagnostic.kind](`[{diagnostic.kind} {diagnostic.code}]`))
	if diagnostic.message then
		stream:append(`: {diagnostic.message}`)
	end
	stream:append("\n")

	local all_labels = diagnostic.labels
	local files_to_render: { [number]: true } = {}
	for _, label in all_labels do
		files_to_render[label.span.z] = true
	end

	for file_id in files_to_render do
		local file_to_render = assert_panic(file.from_id(file_id), "Expected a file to render")

		local file_labels = table.create(#all_labels) :: { types.Label }
		for _, label in all_labels do
			if label.span.z == file_id then
				table.insert(file_labels, label)
			end
		end

		local file_layout = layout.from_labels(file_labels)
		local file_lines = file.as_lines(file_to_render)
		local layout_lines = file_layout.lines
		local max_multiline_nesting = file_layout.max_multiline_nesting

		local max_line_number_width = (layout_lines[#layout_lines].index // 10 + 1)
		local function append_margin(padding: string, border: string, line_number: number?)
			stream:append(padding)
			if line_number then
				stream:append(string.rep(padding, max_line_number_width - (math.log10(line_number) // 1 + 1)))
				stream:append(DIM(tostring(line_number)))
			else
				stream:append(string.rep(padding, max_line_number_width))
			end
			stream:append(padding)
			stream:append(border)
		end

		-- header
		do
			local first_line = layout_lines[1].index
			local last_line = layout_lines[#layout_lines].index

			append_margin(" ", CHAR_SET.margin_top_left)
			stream:append(`[{file_to_render.name}:{first_line}:{last_line}]\n`)
		end

		for _, line in layout_lines do
			local line_index = line.index
			local file_line = file_lines[line_index] :: vector?
			if file_line == nil then
				return panic(
					`expected line index {line_index} to map to a line in file {file_id}, max line {#file_lines}`
				)
			end

			local line_source =
				buffer.readstring(file_to_render.buffer, file_line.x, math.max(0, (file_line.y - file_line.x)))
			line_source = string.gsub(line_source, "\n", "")

			local inlines = line.inlines
			local multilines = line.multilines
			local multiline_padding = string.rep(" ", 4)

			local function append_multiline_edge(is_source: boolean)
				for index = 1, max_multiline_nesting do
					local multiline: layout.MultilineLayout?
					for _, value in multilines do
						if value.line_index == index then
							multiline = value
							break
						end
					end

					if multiline == nil then
						continue
					end

					local insert = ""
					local label = multiline.label
					local segment = multiline.segment
					if is_source and segment.start.line == line_index then
						insert = `{CHAR_SET.label_top_left}{CHAR_SET.label_h}{CHAR_SET.arrow_right}`
					elseif is_source and segment.finish.line == line_index then
						local connection = label.message and CHAR_SET.right_cross or CHAR_SET.label_bottom_left
						insert = `{connection}{CHAR_SET.label_h}{CHAR_SET.arrow_right}`
					elseif is_source or line_index < segment.finish.line then
						insert = CHAR_SET.label_v
					end

					local raw_insert = insert
					local style = label.style
					if style and insert ~= "" then
						insert = style(insert)
					end

					stream:append(overlap(insert, multiline_padding, raw_insert))
				end
			end

			-- source line
			append_margin(" ", CHAR_SET.margin_bar, line_index)
			append_multiline_edge(true)
			stream:append(" ")
			append_source(stream, line_source, function(char: string, first: number, last: number): string
				for _, inline in inlines do
					local style = inline.label.style
					if style == nil then
						continue
					end

					local segment = inline.segment
					if first >= segment.start.offset and last <= segment.finish.offset then
						return style(char)
					end
				end

				for _, multiline in multilines do
					local style = multiline.label.style
					if style == nil then
						continue
					end

					local segment = multiline.segment
					if
						(segment.start.line == line_index and first >= segment.start.offset)
						or (segment.finish.line == line_index and first <= segment.finish.offset)
					then
						return style(char)
					end
				end

				return char
			end)
			stream:append("\n")

			-- inlines
			if #inlines > 0 then
				append_margin(" ", CHAR_SET.margin_bar_skip)
				append_multiline_edge(false)

				stream:append(" ")
				append_underlines(stream, line_source, function(first: number, last: number): string
					local style
					local underline = " "

					for _, inline in inlines do
						local label = inline.label
						local segment = inline.segment

						if label.message and first <= inline.offset and last >= inline.offset then
							style = label.style
							underline = CHAR_SET.arrow_underconnect
						elseif segment.start.offset <= first and last <= segment.finish.offset then
							style = label.style
							underline = CHAR_SET.arrow_underline
						end

						if underline ~= " " then
							break
						end
					end

					if style then
						underline = style(underline)
					end

					return underline
				end)

				stream:append("\n")

				for inline_draw_index = #inlines, 1, -1 do
					append_margin(" ", CHAR_SET.margin_bar_skip)
					append_multiline_edge(false)
					stream:append(" ")

					append_underlines(stream, line_source, function(first: number, last: number): string
						local style
						local underline = " "

						for inline_index, inline in inlines do
							local label = inline.label
							if label.message == nil then
								continue
							end

							if first <= inline.offset and last >= inline.offset then
								if inline_index == inline_draw_index then
									underline = CHAR_SET.label_bottom_left
								elseif inline_draw_index > inline_index then
									underline = CHAR_SET.label_v
								end
							end

							if inline_index == inline_draw_index then
								local segment = inline.segment
								if last <= segment.finish.offset and first > inline.offset then
									underline = CHAR_SET.label_h
								end
								if first == segment.finish.offset or last == segment.finish.offset then
									underline = `{underline} {label.message}`
								end
							end

							if underline ~= " " then
								style = label.style
								break
							end
						end

						if style then
							underline = style(underline)
						end

						return underline
					end)

					stream:append("\n")
				end
			end

			-- multilines
			local finishing_multilines: { layout.MultilineLayout } = {}
			for _, multiline in multilines do
				if multiline.label.message == nil then
					continue
				end

				if multiline.segment.finish.line == line_index then
					table.insert(finishing_multilines, multiline)
				end
			end

			if #finishing_multilines > 0 then
				local function append_finishing_edges(line_index: number, is_message: boolean)
					for _, multiline in multilines do
						if is_message and multiline.line_index == line_index then
							continue
						end

						if multiline.line_index > line_index then
							continue
						end

						local label = multiline.label
						local style = multiline.label.style or NOOP_STYLE
						local insert = label.message and CHAR_SET.label_v or ""
						stream:append(overlap(style(insert), multiline_padding, insert))
					end
				end

				table.sort(finishing_multilines, function(a: any, b)
					return a.line_index < b.line_index
				end)

				for index = #finishing_multilines, 1, -1 do
					local multiline = finishing_multilines[index]
					local multiline_line_index = multiline.line_index

					append_margin(" ", CHAR_SET.margin_bar_skip)
					append_finishing_edges(multiline_line_index, false)
					stream:append("\n")

					append_margin(" ", CHAR_SET.margin_bar_skip)
					append_finishing_edges(multiline_line_index, true)

					local label = multiline.label
					local style = label.style or NOOP_STYLE

					stream:append(style(CHAR_SET.label_bottom_left))
					stream:append(string.rep(style(CHAR_SET.label_h), 2))
					stream:append(" ")
					stream:append(style(label.message :: string))

					stream:append("\n")
				end
			end
		end

		-- footer
		append_margin(CHAR_SET.margin_h, CHAR_SET.margin_bottom_right)
		stream:append("\n")
	end

	return stream:finalize()
end

return render
