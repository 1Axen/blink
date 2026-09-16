--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type ProjCall<T> = types.ProjCall<T>
type Readable<T> = types.Readable<T>

local function traceback(message: Readable<string>, level: Readable<number>?): ProjCall<string>
	return projection.call(constant.from_value("debug.traceback"), { message, level } :: any)
end

local function traceback_thread(
	thread: Readable<thread>,
	message: Readable<string>,
	level: Readable<number>?
): ProjCall<string>
	return projection.call(constant.from_value("debug.traceback"), { thread, message, level } :: any)
end

return table.freeze({
	traceback = traceback,
	traceback_thread = traceback_thread,
})
