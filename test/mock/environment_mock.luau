local brick_color_mock = require("./brick_color_mock")
local cframe_mock = require("./cframe_mock")
local color3_mock = require("./color3_mock")
local data_model_mock = require("./data_model_mock")
local date_time_mock = require("./date_time_mock")
local task = require("@std/task")
local typeof_mock = require("./typeof_mock")

export type Environment = { [any]: any }
type DataModelMock = data_model_mock.DataModelMock

return function(data_model: DataModelMock?): Environment
	return table.freeze({
		game = data_model,

		type = type,
		warn = print,
		print = print,
		error = error,
		pcall = pcall,
		bit32 = bit32,
		debug = debug,
		assert = assert,
		task = task,
		math = math,
		table = table,
		buffer = buffer,
		vector = vector,
		string = string,
		coroutine = coroutine,

		typeof = typeof_mock,
		Color3 = color3_mock,
		CFrame = cframe_mock,
		DateTime = date_time_mock,
		BrickColor = brick_color_mock,
		Instance = table.freeze({ new = data_model_mock.instance_new }),
	}) :: { [any]: any }
end
