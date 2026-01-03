--!strict

local types = require("@lir/types")

type RValue<T = any> = types.RValue<T>
type Condition = types.Condition<boolean>

local function condition(kind: index<Condition, "kind">)
	return function<A, B>(left: RValue<A>, right: RValue<B>): Condition
		return {
			__phantom_type = nil :: any,

			type = "condition",
			kind = kind,
			left = left,
			right = right,
		}
	end
end

return table.freeze({
	oor = condition("or"),
	aand = condition("and"),
	equals = condition("equals"),
	not_equals = condition("not_equals"),
	less_than = condition("less_than"),
	less_than_or = condition("less_than_or"),
	greater_than = condition("greater_than"),
	greater_than_or = condition("greater_than_or"),
})
