local literal = require("@self/literal")
local numeral = require("@self/numeral")
local tableext = require("@std/tableext")
local types = require("@self/types")

export type Datatype = types.Datatype

local single_primitives = {
	string = require("@self/string"),
	buffer = require("@self/buffer"),
	vector = require("@self/vector"),
	boolean = require("@self/boolean"),
}

type Primitives = typeof(single_primitives) & typeof(literal) & typeof(numeral)
local primitives = tableext.combine(single_primitives, numeral :: any, literal :: any)

return table.freeze({
	structures = table.freeze({
		map = require("@self/map"),
		array = require("@self/array"),
		union = require("@self/union"),
		struct = require("@self/struct"),
		discriminated_union = require("@self/discriminated_union"),
	}),
	primitives = table.freeze(primitives :: Primitives),
})
