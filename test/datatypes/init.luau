local literal = require("@self/literal")
local numeral = require("@self/numeral")
local string_builder = require("@util/string_builder")
local tableext = require("@std/tableext")
local types = require("@self/types")

export type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local single_primitives = {
	string = require("@self/string"),
	buffer = require("@self/buffer"),
	vector = require("@self/vector"),
	boolean = require("@self/boolean"),
	Color3 = require("@self/color3"),
	CFrame = require("@self/cframe"),
	DateTime = require("@self/date_time"),
	BrickColor = require("@self/brick_color"),
	DateTimeMillis = require("@self/date_time_millis"),
}

type Primitives = typeof(single_primitives) & typeof(literal) & typeof(numeral)
local primitives = tableext.combine(single_primitives, numeral :: any, literal :: any)

local primitives_array: { [number]: Datatype } = {}
for _, datatype in primitives do
	table.insert(primitives_array :: any, datatype)
end

local unknown: Datatype = table.freeze({
	append = function(builder: StringBuilder)
		builder:append("unknown")
	end,
	generate = function(seed: number)
		local index = math.max(1, seed % (#primitives + 1))
		return primitives_array[index].generate(seed)
	end,
})

return table.freeze({
	roblox = table.freeze({
		unknown = unknown,
		instance = require("@self/instance"),
		streamed_instance = require("@self/streamed_instance"),
	}),
	structures = table.freeze({
		map = require("@self/map"),
		array = require("@self/array"),
		union = require("@self/union"),
		struct = require("@self/struct"),
		optional = require("@self/optional"),
		discriminated_union = require("@self/discriminated_union"),
	}),
	primitives = table.freeze(primitives :: Primitives),
})
