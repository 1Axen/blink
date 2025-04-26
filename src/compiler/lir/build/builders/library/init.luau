--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

local math_lib = require("./math")
local bit32_lib = require("./bit32")
local table_lib = require("./table")
local vector_lib = require("./vector")
local buffer_lib = require("./buffer")
local roblox_lib = require("./roblox")
local coroutine_lib = require("./coroutine")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function luau_error(message: string): Call<nil>
    return projection.call(
        constant.from_value("error"),
        {constant.from_value(message)} :: any
    )
end

local function luau_typeof(of: RValue<any>): Call<string>
    return projection.call(
        constant.from_value("typeof"),
        {of}
    )
end

local function luau_tostring(value: RValue<any>): Call<string>
    return projection.call(
        constant.from_value("typeof"),
        {value}
    )
end

return table.freeze({
    error = luau_error,
    typeof = luau_typeof,
    tostring = luau_tostring,

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
})