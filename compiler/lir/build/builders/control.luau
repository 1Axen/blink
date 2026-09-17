--!strict

local types = require("@lir/types")

type Readable<T> = types.Readable<T>

local function ctrl_advance(bytes: Readable<number>): types.CtrlAdvance<number>
	return {
		__readable = nil :: any,
		type = "control",
		kind = "advance",
		bytes = bytes :: any,
	}
end

local function ctrl_allocate(bytes: Readable<number>): types.CtrlAllocate<nil>
	return {
		type = "control",
		kind = "allocate",
		bytes = bytes :: any,
	}
end

return table.freeze({
	advance = ctrl_advance,
	allocate = ctrl_allocate,
})
