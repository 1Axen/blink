local range = require("@util/range")

local F64 = 2 ^ 53
local F32 = 2 ^ 24

return table.freeze({
	map = range.sealed_from_usize(32),
	array = range.sealed_from_usize(32),

	u8 = range.sealed_from_usize(8),
	u16 = range.sealed_from_usize(16),
	u24 = range.sealed_from_usize(24),
	u32 = range.sealed_from_usize(32),
	u48 = range.sealed_from_usize(48),

	i8 = range.sealed_from_size(8),
	i16 = range.sealed_from_size(16),
	i24 = range.sealed_from_size(24),
	i32 = range.sealed_from_size(32),
	i48 = range.sealed_from_size(48),

	f32 = range.sealed(-F32, F32),
	f64 = range.sealed(-F64, F64),

	string = range.sealed_from_usize(32),
	-- https://github.com/luau-lang/luau/blob/d0222bb55465e05f03d4e4a84f7eb53d49c0c3f4/VM/src/lbuffer.h#L7
	buffer = range.sealed_from_usize(30),
	vector = range.sealed(-F64, F64),
})
