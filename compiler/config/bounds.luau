local range = require("@util/range")

local F64 = 2 ^ 53
local F32 = 2 ^ 24
local F16 = 2 ^ 10

return table.freeze({
	map = range.from_usize(32),
	array = range.from_usize(32),

	u8 = range.from_usize(8),
	u16 = range.from_usize(16),
	u24 = range.from_usize(24),
	u32 = range.from_usize(32),
	u48 = range.from_usize(48),

	i8 = range.from_size(8),
	i16 = range.from_size(16),
	i24 = range.from_size(24),
	i32 = range.from_size(32),
	i48 = range.from_size(48),

	f16 = range.create(-F16, F16),
	f32 = range.create(-F32, F32),
	f64 = range.create(-F64, F64),

	string = range.from_usize(32),
	-- https://github.com/luau-lang/luau/blob/d0222bb55465e05f03d4e4a84f7eb53d49c0c3f4/VM/src/lbuffer.h#L7
	buffer = range.from_usize(30),
	vector = range.create(-F64, F64),
})
