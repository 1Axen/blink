local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("vector")
end

local function generate()
	return vector.create(math.random(), math.random(), math.random())
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
