--!strict
--!native
--!optimize 2

export type Config = {
	read tab_width: number,
	read use_spaces: boolean,
}

export type StringBuilder = {
	buffer: buffer,
	indent: number,
	length: number,
	position: number,
} & Config

local GROWTH_FACTOR = 1.5
local DEFAULT_LENGTH = 1024

local DEFAULT_CONFIG: Config = {
	tab_width = 4,
	use_spaces = false,
}

type function optional_keys(table: type)
	local new_table = types.newtable()
	for key, prop in table:properties() do
		if prop.read then
			local value = types.unionof(prop.read, types.singleton(nil))
			new_table:setreadproperty(key, value)
		end

		if prop.write then
			local value = types.unionof(prop.write, types.singleton(nil))
			new_table:setwriteproperty(key, value)
		end
	end

	return new_table
end

--> keep a list of buffers to recycle instead of creating new ones
local recycling_bin: { buffer } = {}

local function borrow_buffer(): buffer
	if #recycling_bin == 0 then
		return buffer.create(DEFAULT_LENGTH)
	end

	return table.remove(recycling_bin, 1) :: buffer
end

local function return_buffer(buf: buffer, position: number)
	table.insert(recycling_bin, buf)
end

local function create(config: optional_keys<Config>): StringBuilder
	local recycled_buffer = borrow_buffer()
	return {
		buffer = recycled_buffer,
		length = buffer.len(recycled_buffer),
		indent = 0,
		position = 0,
		tab_width = config.tab_width or DEFAULT_CONFIG.tab_width,
		use_spaces = config.use_spaces or DEFAULT_CONFIG.use_spaces,
	}
end

local function write(builder: StringBuilder, str: string)
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

local function indent(builder: StringBuilder)
	builder.indent += 1
end

local function dedent(builder: StringBuilder)
	builder.indent -= 1
end

local function append_indent(builder: StringBuilder)
	if builder.use_spaces then
		write(builder, string.rep(" ", builder.tab_width * builder.indent))
	else
		write(builder, string.rep("\t", builder.indent))
	end
end

local function append(builder: StringBuilder, str: string)
	write(builder, str)
end

local function append_line(builder: StringBuilder, str: string)
	append_indent(builder)
	append(builder, str)
	write(builder, "\n")
end

local function append_lines(builder: StringBuilder, lines: { string })
	for _, line in lines do
		append_line(builder, line)
	end
end

local function finalize(builder: StringBuilder): string
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
	finalize = finalize,
})
