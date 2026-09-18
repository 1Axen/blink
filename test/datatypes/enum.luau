local enum_mock = require("@test/mock/enum_mock")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

const ENUMS = enum_mock.ENUMS

local function append(builder: StringBuilder)
	builder:append(`Enum<"Axis">`)
end

local function generate(seed: number)
	const items = ENUMS.Axis:GetEnumItems()
	return items[((seed - 1) % #items) + 1]
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
