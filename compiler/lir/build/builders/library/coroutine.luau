--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type Readable<T> = types.Readable<T>

type Status = typeof(coroutine.status(nil :: any))

local function create(fn: Readable<any>): Call<thread>
	return projection.call(constant.from_value("coroutine.create"), { fn })
end

local function running(): Call<thread>
	return projection.call(constant.from_value("coroutine.running"), {})
end

local function resume(thread: Readable<thread>, ...: Readable<any>): Call<nil>
	return projection.call(constant.from_value("coroutine.resume"), { thread, ... })
end

local function status(thread: Readable<thread>): Call<Status>
	return projection.call(constant.from_value("coroutine.status"), { thread })
end

local function yield(): Call<any>
	return projection.call(constant.from_value("coroutine.yield"), {})
end

local function close(thread: Readable<thread>): Call<nil>
	return projection.call(constant.from_value("coroutine.close"), { thread })
end

return table.freeze({
	create = create,
	resume = resume,
	status = status,
	running = running,
	yield = yield,
	close = close,
})
