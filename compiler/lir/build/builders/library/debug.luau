--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type RValue<T> = types.RValue<T>
type ProjCall<T> = types.ProjCall<T>

local function traceback(message: RValue<string>, level: RValue<number>?): ProjCall<string>
	return projection.call(constant.from_value("debug.traceback"), { message, level } :: any)
end

local function traceback_thread(
	thread: RValue<thread>,
	message: RValue<string>,
	level: RValue<number>?
): ProjCall<string>
	return projection.call(constant.from_value("debug.traceback"), { thread, message, level } :: any)
end

return table.freeze({
	traceback = traceback,
	traceback_thread = traceback_thread,
})
