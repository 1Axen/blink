--!strict

local types = require("@lir/types")

type RValue<T> = types.RValue<T>
type Readable<T = any> = types.Readable<T>
type Condition = types.Condition<boolean>

local function ternary<T>(cond: Condition, left: Readable<T>, right: Readable<T>): types.Ternary<T>
	return {
		__readable = nil :: any,

		type = "ternary",
		cond = cond,
		left = left :: RValue<T>,
		right = right :: RValue<T>,
	}
end

return ternary
