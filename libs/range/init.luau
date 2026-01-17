--!strict
--!native
--!optimize 2

export type UnsealedRange = {
	read min: number?,
	read max: number?,
}

export type SealedRange = {
	read min: number,
	read max: number,
}

local function create_sealed_range(min: number, max: number): SealedRange
	return table.freeze({
		min = min,
		max = max,
	})
end

local function create_unsealed_range(min: number?, max: number?): UnsealedRange
	return table.freeze({
		min = min,
		max = max,
	})
end

--- Returns a range bounded to the minimum and maximum signed value representable in `bits` bits
local function sealed_from_size(bits: number): SealedRange
	--> lose one bit for the sign
	local max = (2 ^ (bits - 1))
	local min = -max

	return create_sealed_range(min, max - 1)
end

--- Returns a range bounded to the minimum and maximum unsigned value representable in `bits` bits
local function sealed_from_usize(bits: number): SealedRange
	return create_sealed_range(0, (2 ^ bits) - 1)
end

return table.freeze({
	sealed = create_sealed_range,
	unsealed = create_unsealed_range,
	sealed_from_size = sealed_from_size,
	sealed_from_usize = sealed_from_usize,
})
