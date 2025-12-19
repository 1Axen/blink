local cframe_mock = require("@test/mock/cframe_mock")
local random_float = require("@util/random_float")
local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local MAX = 2 ^ 16

local function random_quaternion()
	return vector.create(random_float(-1, 1), random_float(-1, 1), random_float(-1, 1)), random_float(-1, 1)
end

local function append(builder: StringBuilder)
	builder:append("CFrame")
end

local function generate()
	local position = vector.create(random_float(-MAX, MAX), random_float(-MAX, MAX), random_float(-MAX, MAX))
	local quat_vector, quat_scalar = random_quaternion()
	return cframe_mock.new(position.x, position.y, position.z, quat_vector.x, quat_vector.y, quat_vector.z, quat_scalar)
end

local datatype: Datatype = table.freeze({
	append = append,
	generate = generate,
})

return datatype
