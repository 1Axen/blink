--!strict
--!native
--!optimize 2

export type Builder = {
	indent: number,
	buffer: buffer,
	length: number,
	position: number,
	tab_width: number,
}

local TAB_WIDTH = 4
local GROWTH_FACTOR = 1.5
local DEFAULT_LENGTH = 1024

--> keep a list of buffers to recycle instead of creating new ones
local recycling_bin: {buffer} = {}

local function borrow_buffer(): buffer
    if #recycling_bin == 0 then
        return buffer.create(DEFAULT_LENGTH)
    end

    return table.remove(recycling_bin, 1) :: buffer
end

local function return_buffer(buf: buffer, position: number)
    table.insert(recycling_bin, buf)
end

local function create(): Builder
    local recycled_buffer = borrow_buffer()

	return {
		indent = 0,
		buffer = recycled_buffer,
		length = buffer.len(recycled_buffer),
		position = 0,
		tab_width = TAB_WIDTH
	}
end

local function write(builder: Builder, str: string)
	local bytes = #str
	if bytes == 0 then
		return
	end

	local buf = builder.buffer
	local length = builder.length
	local position = builder.position

	local new_position = (position + bytes)
	if new_position >= length then
		local new_length = length * GROWTH_FACTOR
		while new_position >= new_length do
			new_length *= GROWTH_FACTOR
		end

		local new_buf = buffer.create(new_length)
		buffer.copy(new_buf, 0, buf, 0, position)

		buf = new_buf
		builder.buffer = new_buf
		builder.length = new_length
	end

	buffer.writestring(buf, position, str, bytes)
	builder.position = (position + bytes)
end

local function indent(builder: Builder)
	builder.indent += 1
end

local function dedent(builder: Builder)
	builder.indent -= 1
end

local function append_indent(builder: Builder)
	write(builder, string.rep(" ", builder.tab_width * builder.indent))
end

local function append(builder: Builder, str: string)
	write(builder, str)
end

local function append_line(builder: Builder, str: string)
	append_indent(builder)
	append(builder, str)
	write(builder, "\n")
end

local function append_lines(builder: Builder, lines: {string})
	for _, line in lines do
		append_line(builder, line)
	end
end

local function set_tab_width(builder: Builder, width: number)
	builder.tab_width = width
end

local function to_string(builder: Builder): string
    local str = buffer.readstring(builder.buffer, 0, builder.position)
    return_buffer(builder.buffer, builder.position)
	return str
end

return table.freeze({
	create = create,
	indent = indent,
	dedent = dedent,
	append = append,
	append_line = append_line,
	append_lines = append_lines,
	append_indent = append_indent,
	set_tab_width = set_tab_width,
	to_string = to_string,
})