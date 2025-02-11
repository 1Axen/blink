--!strict

local expect = require("./expect")
local colorful = require("@vendor/colorful")

type Case = {
	read name: string,
	skip: boolean,
	focus: boolean,
	error: string?,
	success: boolean,
}

type Test = {
	read name: string,
	case: Case?,
	read cases: {Case},
	focus: boolean,
	error: string?,
}

local WALL = colorful.modifier.dim("|")
local TITLE = colorful.combineStyles({colorful.color.white, colorful.modifier.bold, colorful.modifier.underline})

local skip = false
local focused = false

local test: Test?
local tests: {Test} = {}

local function print_test_result(test: Test)
	if focused then
		local is_focused = test.focus
		for _, case in test.cases do
			is_focused = is_focused or case.focus
		end

		if is_focused == false then
			return
		end
	end

	print(TITLE(test.name))
	
	for _, case in test.cases do
		local status = colorful.color.green("PASS")
		if case.skip then
			status = colorful.color.yellow("SKIP")
		elseif case.success == false then
			status = colorful.color.red("FAIL")
		end

		print(`{status}{WALL} {case.name}`)

		if case.error and case.skip == false then
			print(colorful.color.gray(case.error))
		end
	end
	
	if test.error then
		print(colorful.color.gray(test.error))
	end

	print()
end

local function TEST(name: string, fn: () -> ())
	-- getting a weird type state mutation
	assert(test == nil, "Cannot start a test while another is running")

	test = {
		name = name,
		cases = {},
		focus = false,
	} :: Test

	table.insert(tests, test)

	local err: string?
	local success = xpcall(fn, function(message: string)
		err = debug.traceback(tostring(message), 2)
	end)

	if success == false then
		test.error = err
	end

	test = nil
end

local function CASE(name: string, fn: () -> ())
	-- getting a weird type state mutation
	assert(test ~= nil, "No active test")

	skip = false

	local case: Case = {
		name = name,
		skip = false,
		focus = false,
		success = true,
	}

	test.case = case
	table.insert(test.cases, case)

	local err: string?
	local success = xpcall(fn, function(message: string)
		err = debug.traceback(message, 2)
	end)

	case.skip = skip
	case.error = err
	case.success = success
end

local function SKIP()
	skip = true
end

local function FOCUS()
	assert(test ~= nil, "No active test")

	if test.case then
		test.case.focus = true
	else
		test.focus = true
	end

	focused = true
end

local function finish(): boolean
	local success = true
	local total_cases = 0
	local passed_cases = 0
	local total_focus_cases = 0
	local passed_focus_cases = 0

	for _, test in tests do
		if test.error then
			success = false
		end

		for _, case in test.cases do
			local is_focused = (case.focus or test.focus)
			total_cases += 1
			
			if is_focused then
				total_focus_cases += 1
			end

			if case.success or case.skip then
				if is_focused then
					passed_focus_cases += 1
				end

				passed_cases += 1
			else
				success = false
			end
		end

		print_test_result(test)
	end

	print(colorful.color.gray(`{passed_cases}/{total_cases} test cases passed`))

	if focused then
		print(colorful.color.gray(`{passed_focus_cases}/{total_focus_cases} focused test cases passed`))
	end

	local fails = (total_cases - passed_cases)
	local color = (fails > 0 and colorful.color.red or colorful.color.green)
	
	print(color(`{fails} {fails == 1 and "fail" or "fails"}`))

	focused = false
	return success
end

return table.freeze({
	test = function()
		return TEST, CASE, SKIP, FOCUS, expect
	end,

	expect = expect,
	finish = finish
})