--!strict

local types = require("@lir/types")

type RValue<T> = types.RValue<T>

local function ctrl_advance(bytes: RValue<number>): types.CtrlAdvance<number>
	return {
		__phantom_type = nil :: any,

		type = "control",
		kind = "advance",
		bytes = bytes :: any,
	}
end

local function ctrl_allocate(bytes: RValue<number>): types.CtrlAllocate<nil>
	return {
		__phantom_type = nil,
		type = "control",
		kind = "allocate",
		bytes = bytes :: any,
	}
end

return table.freeze({
	advance = ctrl_advance,
	allocate = ctrl_allocate,
})
