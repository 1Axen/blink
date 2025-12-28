local data_model_mock = require("@test/mock/data_model_mock")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("Instance")
end

local function generate()
	return data_model_mock.instance_new("Instance")
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
