--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type RValue<T> = types.RValue<T>

local function bor(...: RValue<number>): Call<number>
	return projection.call(constant.from_value("bit32.bor"), { ... })
end

local function bxor(...: RValue<number>): Call<number>
	return projection.call(constant.from_value("bit32.bxor"), { ... })
end

local function lshift(x: RValue<number>, disp: types.Constant<number>): Call<number>
	return projection.call(constant.from_value("bit32.lshift"), { x, disp })
end

local function rshift(x: RValue<number>, disp: types.Constant<number>): Call<number>
	return projection.call(constant.from_value("bit32.rshift"), { x, disp })
end

local function countrz(n: RValue<number>): Call<number>
	return projection.call(constant.from_value("bit32.countrz"), { n })
end

return table.freeze({
	bor = bor,
	bxor = bxor,
	lshift = lshift,
	rshift = rshift,
	countrz = countrz,
})
