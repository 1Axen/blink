local date_time_mock = require("@test/mock/date_time_mock")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("DateTime")
end

local function generate()
	local timestamp = os.time() + math.random(-2 ^ 16, 2 ^ 16)
	return date_time_mock.fromUnixTimestamp(timestamp // 1)
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
