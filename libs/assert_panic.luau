local panic = require("@util/panic")

local function assert_panic<T>(value: T, final_words: string): typeof(assert(nil :: T))
	if value == false or value == nil then
		return panic(final_words)
	end

	return value
end

return assert_panic
