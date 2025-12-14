local range = require("@util/range")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Range = range.Range
type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function factory(value: any): Datatype
	return table.freeze({
		append = function(builder: StringBuilder)
			local stringifed = tostring(value)
			if type(value) == "string" then
				stringifed = `"{stringifed}"`
			end

			builder:append(stringifed)
		end,
		generate = function()
			return value
		end,
	})
end

return table.freeze({
	string_literal = factory("Hello, World!"),
	number_literal = factory(math.pi),
	boolean_literal = factory(true),
})
