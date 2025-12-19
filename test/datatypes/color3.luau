local color3_mock = require("@test/mock/color3_mock")
local random_float = require("@util/random_float")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("Color3")
end

local function generate()
	return color3_mock.fromHSV(random_float(0, math.pi * 2), random_float(0, 1), random_float(0, 1))
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
