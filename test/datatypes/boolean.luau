local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("boolean")
end

local function generate()
	return math.random(0, 1) == 1
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
