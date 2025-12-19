local CHUNK = buffer.create(4)

local function random_float(min: number, max: number): number
	local sign = math.random(0, 1)
	local fraction = math.random()
	if sign == 0 then
		return fraction * min
	end

	local double = fraction * max
	buffer.writef32(CHUNK, 0, double)
	return buffer.readf32(CHUNK, 0)
end

return random_float
