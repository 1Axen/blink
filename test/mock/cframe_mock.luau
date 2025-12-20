local cframe = {}
cframe.__index = cframe
cframe.__tostring = function()
	return "CFrame"
end

local EPSILON = 0.1

type CFrameMock = setmetatable<{
	x: number,
	y: number,
	z: number,
	Position: vector,
	quat_vector: vector,
	quat_scalar: number,
}, typeof(cframe)>

function cframe.new(x: number, y: number, z: number, quat_x: number?, quat_y: number?, quat_z: number?, quat_w: number?)
	quat_x = quat_x or 0
	quat_y = quat_y or 0
	quat_z = quat_z or 0
	quat_w = quat_w or 0

	local quat_vector = vector.create(quat_x, quat_y, quat_y)

	-- ensure the quaternion is normalized
	local magnitude = math.sqrt(vector.dot(quat_vector, quat_vector) + quat_w * quat_w)
	if magnitude == 0 then
		quat_vector = vector.zero
		quat_w = 1
	else
		local inverse_magnitude = 1 / magnitude
		quat_vector *= inverse_magnitude
		quat_w *= inverse_magnitude
	end

	return setmetatable({
		x = x,
		y = y,
		z = z,
		Position = vector.create(x, y, z),
		quat_vector = quat_vector,
		quat_scalar = quat_w,
	}, cframe)
end

function cframe.ToAxisAngle(self: CFrameMock): (vector, number)
	local scalar = self.quat_scalar
	local angle = 2 * math.acos(scalar)
	local scale = math.sqrt(1 - scalar * scalar)
	if scale < 1E-5 then
		return vector.create(1, 0, 0), angle
	end

	return self.quat_vector / scale, angle
end

function cframe.__eq(self: CFrameMock, value: CFrameMock)
	local position_magnitude = vector.magnitude(self.Position - value.Position)
	local quat_magnitude = vector.magnitude(self.quat_vector - value.quat_vector)
	return position_magnitude <= EPSILON
		and quat_magnitude <= EPSILON
		and math.abs(self.quat_scalar - value.quat_scalar) <= EPSILON
end

return cframe
