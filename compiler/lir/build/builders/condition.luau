--!strict

local types = require("@lir/types")

type RValue<T = any> = types.RValue<T>
type Condition = types.Condition<boolean>

local function condition<A, B>(kind: index<Condition, "kind">, left: RValue<A>, right: RValue<B>): Condition
	return {
		__phantom_type = nil :: any,

		type = "condition",
		kind = kind,
		left = left,
		right = right,
	}
end

return table.freeze({
	equals = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("equals", left, right)
	end,
	not_equals = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("not_equals", left, right)
	end,
	less_than = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("less_than", left, right)
	end,
	less_than_or = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("less_than_or", left, right)
	end,
	greater_than = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("greater_than", left, right)
	end,
	greater_than_or = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition("greater_than_or", left, right)
	end,
})
