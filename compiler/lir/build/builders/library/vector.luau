--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type Readable<T> = types.Readable<T>

type Axis = types.Readable<number>

local function create(x: Axis, y: Axis, z: Axis): Call<vector>
	return projection.call(constant.from_value("vector.create"), { x, y, z })
end

local function magnitude(vec: types.Readable<vector>): Call<number>
	return projection.call(constant.from_value("vector.magnitude"), { vec })
end

return table.freeze({
	create = create,
	magnitude = magnitude,
})
