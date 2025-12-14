local bounds = require("@compiler/config/bounds") :: { [string]: Range? }
local range = require("@util/range")
local string_builder = require("@util/string_builder")
local typeforge = require("@util/typeforge")
local types = require("./types")

type Range = range.Range
type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function factory(keyword: string, bounds: Range): Datatype
	local signed = bounds.min < 0
	local floating = string.sub(keyword, 1, 1) == "f"

	return table.freeze({
		append = function(builder: StringBuilder)
			builder:append(keyword)
		end,
		generate = function()
			if floating then
				return math.huge
			end

			local negative = signed and math.random(0, 1) == 1 or false
			local rand = math.random()
			local value = rand * (negative and bounds.min or bounds.max)
			value //= 1

			return value
		end,
	})
end

local numerals = {
	"f32" :: "f32",
	"f64" :: "f64",
	"i8" :: "i8",
	"i16" :: "i16",
	"i24" :: "i24",
	"i32" :: "i32",
	"i48" :: "i48",
	"u8" :: "u8",
	"u16" :: "u16",
	"u24" :: "u24",
	"u32" :: "u32",
	"u48" :: "u48",
}

local primitives = {}
for _, numeral in numerals do
	local numeral_bounds = assert(bounds[numeral])
	primitives[numeral] = factory(numeral, numeral_bounds)
end

return table.freeze(primitives :: typeforge.StringUnionToStruct<index<typeof(numerals), number>, Datatype>)
