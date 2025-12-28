local brick_color_mock = require("./brick_color_mock")
local cframe_mock = require("./cframe_mock")
local color3_mock = require("./color3_mock")
local data_model_mock = require("./data_model_mock")
local date_time_mock = require("./date_time_mock")

local INSTANCE_METATABLE = data_model_mock.INSTANCE_METATABLE

local function get_super_metatable(value: any): any
	local metatable = getmetatable(value)
	while true do
		local super_metatable = getmetatable(metatable)
		if super_metatable == nil then
			break
		end

		metatable = super_metatable
	end
	return metatable
end

local function typeof_mock<T>(value: T): string
	local metatable = get_super_metatable(value)
	if metatable == color3_mock then
		return "Color3"
	elseif metatable == brick_color_mock then
		return "BrickColor"
	elseif metatable == date_time_mock then
		return "DateTime"
	elseif metatable == cframe_mock then
		return "CFrame"
	elseif metatable == INSTANCE_METATABLE then
		return "Instance"
	end

	return typeof(value)
end

return typeof_mock
