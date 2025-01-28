--!strict

local NAN = 0 / 0
local EPSILON = 5 * 10^-7

local function deep_equality(a: any, b: any): boolean
	local type_a = type(a)
	local type_b = type(b)

	if type_a ~= type_b then
		return false
	end

	if type_a == "table" then
		for key, value in a do
			if deep_equality(value, b[key]) == false then
				return false
			end
		end
	
		for key, value in b do
			if deep_equality(value, a[key]) == false then
				return false
			end
		end
	elseif type_a == "buffer" then
		return buffer.tostring(a) == buffer.tostring(b)
	end

	return a == b
end

local function expect(value: any, negate: false?)
	local truth = if negate == nil then true else negate
	local suffix = negate ~= nil and "not " or ""

	local function check(condition: boolean): boolean
		return condition == truth
	end

	--> matchers
	--- Performs a `==` comparison
	local function to_be(expected: any)
		if check(value == expected) == false then
			error(`Expected "{value}" {suffix}to be "{expected}"`)
		end
	end

	--- Performs a deep equality comparison
	local function to_equal(expected: any)
		if check(deep_equality(value, expected)) == false then
			error(`Expected "{value}" {suffix}to be "{expected}"`)
		end
	end

	local function to_be_nan()
		if check(value == NAN) == false then
			error(`Expected "{value}" {suffix}to be NaN`)
		end
	end

	local function to_be_nil()
		if check(value == nil) == false then
			error(`Expected "{value}" {suffix}to be nil`)
		end
	end

	local function to_be_truthy()
		if check(value ~= false and value ~= nil) == false then
			error(`Expected "{value}" {suffix}to be truthy`)
		end
	end

	local function to_be_falsey()
		if check(value == false or value == nil) == false then
			error(`Expected "{value}" {suffix}to be falsey`)
		end
	end

	local function to_be_close_to(number: number, epsilon: number?)
		local distance = math.abs(value - number)
		epsilon = epsilon or EPSILON

		if check(distance <= epsilon) == false then
			error(`Expected {value} {suffix}to be close to {number}`)
		end
	end

	local function to_be_less_than(number: number)
		if check(value < number) == false then
			error(`Expected {value} {suffix}to be less than {number}`)
		end
	end

	local function to_be_greater_than(number: number)
		if check(value > number) == false then
			error(`Expected {value} {suffix}to be greater than {number}`)
		end
	end

	local function to_be_less_than_or_equal(number: number)
		if check(value <= number) == false then
			error(`Expected {value} {suffix}to be less than or equal {number}`)
		end
	end

	local function to_be_greater_than_or_equal(number: number)
		if check(value >= number) == false then
			error(`Expected {value} {suffix}to be greater than or equal {number}`)
		end
	end

	local function to_match(pattern: string)
		if check(string.match(value, pattern) ~= nil) == false then
			error(`Expected {value} {suffix}to match "{pattern}"`)
		end
	end

	local function to_contain_substring(substring: string)
		if check(string.find(value, substring, 1, true) ~= nil) == false then
			error(`Expected "{value}" {suffix}to contain substring "{substring}"`)
		end
	end

	--> Checks if `value` (table) contains `key`
	local function to_contain(key: string)
		if check(value[key] ~= nil) == false then
			error(`Expected {value} {suffix}to contain "{key}"`)
		end
	end

	local function to_throw(pattern: string)
		-- TODO: Remove when type issue is fixed
		local info = debug.info :: any
		local name = info(value :: () -> (), "n")
		local success, err = pcall(value)
		if success then
			error(`Expected "{name}" to throw`)
		end

		if check(string.match(err, pattern) ~= nil) == false then
			error(`Expected from "{name}" {suffix}to throw "{pattern}", got "{err}" instead`)
		end
	end

	local self = {
		to_be = to_be,
		to_equal = to_equal,
		
		to_match = to_match,
		to_throw = to_throw,

		to_be_nan = to_be_nan,
		to_be_nil = to_be_nil,

		to_contain = to_contain,
		to_contain_substring = to_contain_substring,

		to_be_truthy = to_be_truthy,
		to_be_falsey = to_be_falsey,
		to_be_close_to = to_be_close_to,
		to_be_less_than = to_be_less_than,
		to_be_greater_than = to_be_greater_than,
		to_be_less_than_or_equal = to_be_less_than_or_equal,
		to_be_greater_than_or_equal = to_be_greater_than_or_equal
	}

	self.never = if negate == nil then expect(value, false) else self
	return self
end

return expect