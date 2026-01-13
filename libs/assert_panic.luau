local panic = require("@util/panic")

type function Truthy(a)
	return types.intersectionof(a, types.negationof(types.optional(types.singleton(false))))
end

local function assert_panic<T>(value: T, final_words: string): Truthy<T>
	if value == false or value == nil then
		return panic(final_words)
	end

	return value
end

return assert_panic
