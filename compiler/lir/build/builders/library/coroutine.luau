--!strict

local lir = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

type Status = typeof(coroutine.status(nil :: any))

local function create(fn: RValue<any>): Call<thread>
	return projection.call(constant.from_value("coroutine.create"), { fn })
end

local function running(): Call<thread>
	return projection.call(constant.from_value("coroutine.running"), {})
end

local function resume(thread: RValue<thread>, ...: RValue<any>): Call<nil>
	return projection.call(constant.from_value("coroutine.resume"), { thread, ... })
end

local function status(thread: RValue<thread>): Call<Status>
	return projection.call(constant.from_value("coroutine.status"), { thread })
end

local function yield(): Call<any>
	return projection.call(constant.from_value("coroutine.yield"), {})
end

local function close(thread: RValue<thread>): Call<nil>
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
