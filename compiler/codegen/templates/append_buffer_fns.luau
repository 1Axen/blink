local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

local buffer_template = [[
local in_buffer = buffer.create(64)
local in_cursor = 0
local in_length = 64
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

local function load_external_in(buf: buffer, unknown: { any }, cursor: number?)
	in_buffer = buf
	in_cursor = cursor or 0
	in_length = buffer.len(buf)
	in_unknown = table.create(16)
	in_unknown_cursor = 0
end

local function load_external_out(buf: buffer, unknown: { any }, cursor: number?)
	out_buffer = buf
	out_cursor = cursor or 0
	out_length = buffer.len(buf)
	out_unknown = table.create(16)
end

local function load_external_in_fast(buf: buffer, cursor: number, length: number, unknown: { unknown })
	in_buffer = buf
	in_cursor = cursor
	in_length = length
	in_unknown = unknown
	in_unknown_cursor = table.maxn(unknown)
end

local function load_external_out_fast(buf: buffer, cursor: number, length: number, unknown: { unknown })
	out_buffer = buf
	out_cursor = cursor
	out_length = length
	out_unknown = unknown
end
]]

local function append_buffer_fns(builder: StringBuilder)
	builder:append(buffer_template)
end

return append_buffer_fns
