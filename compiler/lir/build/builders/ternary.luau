--!strict

local types = require("@lir/types")

type RValue<T = any> = types.RValue<T>
type Condition = types.Condition<boolean>

local function ternary<T>(cond: Condition, left: RValue<T>, right: RValue<T>): types.Ternary<T>
	return {
		__phantom_type = nil :: any,

		type = "ternary",
		cond = cond,
		left = left,
		right = right,
	}
end

return ternary
