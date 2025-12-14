local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("string")
end

local function generate()
	local length = math.random(0, 64)
	local string_buffer = buffer.create(length)
	for offset = 0, length - 1 do
		local character = math.random(35, 126)
		buffer.writeu8(string_buffer, offset, character)
	end

	return buffer.tostring(string_buffer)
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
