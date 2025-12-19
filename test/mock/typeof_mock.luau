local brick_color_mock = require("./brick_color_mock")
local cframe_mock = require("./cframe_mock")
local color3_mock = require("./color3_mock")
local date_time_mock = require("./date_time_mock")

local function typeof_mock<T>(value: T): string
	local metatable = getmetatable(value)
	if metatable == color3_mock then
		return "Color3"
	elseif metatable == brick_color_mock then
		return "BrickColor"
	elseif metatable == date_time_mock then
		return "DateTime"
	elseif metatable == cframe_mock then
		return "CFrame"
	end

	return typeof(value)
end

return typeof_mock
