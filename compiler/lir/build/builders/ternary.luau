--!strict

local lir = require("@lir/types")

type RValue<T = any> = lir.RValue<T>
type Condition = lir.Condition<boolean>

local function ternary<T>(cond: Condition, left: RValue<T>, right: RValue<T>): lir.Ternary<T>
	return {
		__phantom_type = nil :: any,

		type = "ternary",
		cond = cond,
		left = left,
		right = right,
	}
end

return ternary
