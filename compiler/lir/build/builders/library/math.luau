--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type RValue<T> = types.RValue<T>

local function cos(n: RValue<number>): Call<number>
	return projection.call(constant.from_value("math.cos"), { n })
end

local function sin(n: RValue<number>): Call<number>
	return projection.call(constant.from_value("math.sin"), { n })
end

local function sqrt(n: RValue<number>): Call<number>
	return projection.call(constant.from_value("math.sqrt"), { n })
end

return table.freeze({
	cos = cos,
	sin = sin,
	sqrt = sqrt,
})
