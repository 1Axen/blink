local date_time_mock = require("@test/mock/date_time_mock")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function append(builder: StringBuilder)
	builder:append("DateTimeMillis")
end

local function generate()
	local timestamp = math.random(0, 2 ^ 16)
	timestamp *= 1000
	timestamp //= 1
	return date_time_mock.fromUnixTimestampMillis(timestamp)
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
