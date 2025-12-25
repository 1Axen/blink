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
	oor = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("or", left, right)
	end,
	aand = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("and", left, right)
	end,
	equals = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("equals", left, right)
	end,
	not_equals = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("not_equals", left, right)
	end,
	less_than = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("less_than", left, right)
	end,
	less_than_or = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("less_than_or", left, right)
	end,
	greater_than = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("greater_than", left, right)
	end,
	greater_than_or = function<A, B>(left: RValue<A>, right: RValue<B>)
		return condition<<A, B>>("greater_than_or", left, right)
	end,
})
