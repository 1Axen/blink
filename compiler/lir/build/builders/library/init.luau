--!strict

local bit32_lib = require("@self/bit32")
local buffer_lib = require("@self/buffer")
local constant = require("@builders/constant")
local coroutine_lib = require("@self/coroutine")
local lir = require("@lir/types")
local math_lib = require("@self/math")
local projection = require("@builders/projection")
local roblox_lib = require("@self/roblox")
local table_lib = require("@self/table")
local task_lib = require("@self/task")
local vector_lib = require("@self/vector")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function luau_error(message: string): Call<nil>
	return projection.call(constant.from_value("error"), { constant.from_value(message) } :: any)
end

local function luau_typeof(of: RValue<any>): Call<string>
	return projection.call(constant.from_value("typeof"), { of })
end

local function luau_tostring(value: RValue<any>): Call<string>
	return projection.call(constant.from_value("typeof"), { value })
end

return table.freeze({
	error = luau_error,
	typeof = luau_typeof,
	tostring = luau_tostring,

	task = task_lib,
	math = math_lib,
	bit32 = bit32_lib,
	table = table_lib,
	vector = vector_lib,
	buffer = buffer_lib,
	coroutine = coroutine_lib,

	CFrame = roblox_lib.CFrame,
	Color3 = roblox_lib.Color3,
	DateTime = roblox_lib.DateTime,
	Instance = roblox_lib.Instance,
	BrickColor = roblox_lib.BrickColor,
	RemoteEvent = roblox_lib.RemoteEvent,
	Players = roblox_lib.Players,
	DataModel = roblox_lib.DataModel,
})
