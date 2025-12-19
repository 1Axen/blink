local brick_color_mock = require("@test/mock/brick_color_mock")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("BrickColor")
end

local function generate()
	local index = math.random(0, 2 ^ 8)
	return brick_color_mock.new(index)
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
