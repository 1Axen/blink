local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("buffer")
end

local function generate()
	local size = math.random(0, 64)
	local buff = buffer.create(size)
	for offset = 0, size - 1 do
		local byte = math.random(0, 255)
		buffer.writeu8(buff, offset, byte)
	end

	return buff
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
