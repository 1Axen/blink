--!strict

local constant = require("@builders/constant")
local projection = require("@builders/projection")
local roblox_lib = require("@self/roblox")
local types = require("@lir/types")

type Call<T> = types.ProjCall<T>
type RValue<T> = types.RValue<T>

local function luau_warn(...: RValue<string>): Call<nil>
	return projection.call(constant.from_value("warn"), { ... } :: { RValue<any> })
end

local function luau_print(...: RValue<any>): Call<nil>
	return projection.call(constant.from_value("print"), { ... } :: any)
end

local function luau_error(message: string): Call<nil>
	return projection.call(constant.from_value("error"), { constant.from_value(message) } :: any)
end

local function luau_error_rvalue(message: RValue<string>): Call<nil>
	return projection.call(constant.from_value("error"), { message } :: any)
end

local function luau_pcall(fn: RValue<any>, ...: RValue<any>): Call<any>
	return projection.call(constant.from_value("pcall"), { fn, ... })
end

local function luau_typeof<T>(of: RValue<T>): Call<string>
	return projection.call(constant.from_value("typeof"), { of })
end

local function luau_tostring<T>(value: RValue<T>): Call<string>
	return projection.call(constant.from_value("typeof"), { value })
end

return table.freeze({
	warn = luau_warn,
	print = luau_print,
	error = luau_error,
	pcall = luau_pcall,
	typeof = luau_typeof,
	tostring = luau_tostring,
	error_rvalue = luau_error_rvalue,

	task = require("@self/task"),
	math = require("@self/math"),
	bit32 = require("@self/bit32"),
	debug = require("@self/debug"),
	table = require("@self/table"),
	string = require("@self/string"),
	vector = require("@self/vector"),
	buffer = require("@self/buffer"),
	coroutine = require("@self/coroutine"),

	CFrame = roblox_lib.CFrame,
	Color3 = roblox_lib.Color3,
	DateTime = roblox_lib.DateTime,
	Instance = roblox_lib.Instance,
	BrickColor = roblox_lib.BrickColor,
	RemoteEvent = roblox_lib.RemoteEvent,
	Players = roblox_lib.Players,
	DataModel = roblox_lib.DataModel,
})
