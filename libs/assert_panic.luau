local panic = require("@util/panic")
type Falsy = false?

type function Intersect(a, b)
	return types.intersectionof(a, b)
end

local function assert_panic<T>(value: T, final_words: string): Intersect<T, Falsy>
	if value == false or value == nil then
		return panic(final_words)
	end

	return value
end

return assert_panic
