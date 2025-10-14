local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

local buffer_template = [[
local in_buffer = buffer.create(64)
local in_cursor = 0
local in_unknown: { any } = table.create(16)
local in_unknown_cursor = 1

local out_buffer = buffer.create(1024)
local out_cursor = 0
local out_length = 1024
local out_unknown: { any } = table.create(64)

local function advance(bytes: number): number
	local cursor = in_cursor
	in_cursor = (cursor + bytes) :: number
	return cursor
end

local function allocate(bytes: number)
	local cursor = out_cursor
	local in_use: number = (cursor + bytes)

	if in_use > out_length then
		while in_use > out_length do
			out_length *= 1.5
		end

		local buf = buffer.create(out_length)
		buffer.copy(buf, 0, out_buffer, 0, cursor)
		out_buffer = buf
	end

	out_cursor = in_use
end

]]

local function append_buffer_fns(builder: StringBuilder)
	builder:append(buffer_template)
end

return append_buffer_fns
