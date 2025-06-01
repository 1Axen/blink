--!strict
--!native
--!optimize 2

local range = require("@util/range")

type Range = range.Range
export type Primitive = {
	range: range.Range?,
}

local F64 = 2 ^ 53
local F32 = 2 ^ 24
local F16 = 2 ^ 10

local primitives = {
	--> Numerals
	u8 = { range = range.from_usize(8) },
	u16 = { range = range.from_usize(16) },
	u24 = { range = range.from_usize(24) },
	u32 = { range = range.from_usize(32) },
	u48 = { range = range.from_usize(48) },

	i8 = { range = range.from_size(8) },
	i16 = { range = range.from_size(16) },
	i24 = { range = range.from_size(24) },
	i32 = { range = range.from_size(32) },
	i48 = { range = range.from_size(48) },

	f16 = { range = range.create(-F16, F16) },
	f32 = { range = range.create(-F32, F32) },
	f64 = { range = range.create(-F64, F64) },

	--> Luau primitives
	string = { range = range.from_usize(32) },
	-- https://github.com/luau-lang/luau/blob/d0222bb55465e05f03d4e4a84f7eb53d49c0c3f4/VM/src/lbuffer.h#L7
	buffer = { range = range.from_usize(30) },
	vector = {
		range = range.create(-F64, F64),
	},
	boolean = {},

	--> ROBLOX types
	Enum = {},
	CFrame = {},

	Color3 = {},
	BrickColor = {},
	Instance = {},

	DateTime = {},
	DateTimeMillis = {},

	--> Blink types
	unknown = {},
}

return table.freeze(primitives)
