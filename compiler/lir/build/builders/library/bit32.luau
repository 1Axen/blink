--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type Readable<T> = types.Readable<T>

local function bor(...: Readable<number>): Call<number>
	return projection.call(constant.from_value("bit32.bor"), { ... })
end

local function bxor(...: Readable<number>): Call<number>
	return projection.call(constant.from_value("bit32.bxor"), { ... })
end

local function lshift(x: Readable<number>, disp: types.Constant<number>): Call<number>
	return projection.call(constant.from_value("bit32.lshift"), { x, disp })
end

local function rshift(x: Readable<number>, disp: types.Constant<number>): Call<number>
	return projection.call(constant.from_value("bit32.rshift"), { x, disp })
end

local function countrz(n: Readable<number>): Call<number>
	return projection.call(constant.from_value("bit32.countrz"), { n })
end

return table.freeze({
	bor = bor,
	bxor = bxor,
	lshift = lshift,
	rshift = rshift,
	countrz = countrz,
})
