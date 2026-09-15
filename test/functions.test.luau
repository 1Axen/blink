local compiler = require("@compiler")
local data_model_mock = require("@test/mock/data_model_mock")
local datatypes = require("./datatypes")
local fs = require("@util/fs")
local path = require("@util/path")
local playtest_solo = require("@test/utils/playtest_solo")
local string_builder = require("@util/string_builder")
local task = require("@std/task")
local write_targets = require("@test/utils/write_targets")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type Datatype = datatypes.Datatype
type PlayerMock = data_model_mock.PlayerMock
type InstanceMock = data_model_mock.InstanceMock
type DataModelMock = data_model_mock.DataModelMock

type Targets = typeof(compiler.compile_contents(nil :: any, nil :: any))

type Data = { Datatype }

type Function = {
	read data: Data,
	read ret: Data,
}
type Functions = { [string]: Function }

type ClientAPI = {
	exports: {
		[string]: {
			invoke: (...any) -> ...any,
		},
	},
	step_replication: () -> (),
}

type ServerAPI = {
	exports: {
		[string]: {
			on: ((player: PlayerMock, ...any) -> ...any) -> () -> (),
		},
	},
	step_replication: () -> (),
}

local FILE = "functions"
local TEMP_PATH = path.from_string("./temp")

local function await(routine: thread, timeout: number): boolean
	local elapsed = 0
	while coroutine.status(routine) ~= "dead" do
		elapsed += task.wait()
		if elapsed >= timeout then
			return false
		end
	end

	return true
end

local function create_function(data: Data, ret: Data): Function
	return table.freeze({
		data = data,
		ret = ret,
	})
end

local function compile_functions(events: Functions): Targets
	local builder = string_builder.create({})
	builder:append_line("option manual_replication = true")

	for name, event in events do
		builder:append_line(`function {name} = \{`)
		builder:indent()

		builder:append_indent()
		builder:append("data: (")
		for index, datatype in event.data do
			if index > 1 then
				builder:append(", ")
			end

			datatype.append(builder)
		end
		builder:append("),\n")

		builder:append_indent()
		builder:append("return: (")
		for index, datatype in event.ret do
			if index > 1 then
				builder:append(", ")
			end

			datatype.append(builder)
		end
		builder:append(")\n")
		builder:dedent()

		builder:append_line("}")
	end

	local contents = builder:finalize()
	local blink_file_path = path.append_file_name(TEMP_PATH, FILE, "blink")
	assert(fs.write_string_to_file(blink_file_path, contents).ok, "blink file write failed")

	return compiler.compile_contents(contents, {
		profile = "test",
	})
end

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	local functions: Functions = {}
	functions.Single = create_function({ datatypes.primitives.u8 }, { datatypes.primitives.string })
	functions.Multiple = create_function(
		{ datatypes.primitives.u8, datatypes.primitives.u16 },
		{ datatypes.primitives.string, datatypes.primitives.boolean }
	)

	const targets = compile_functions(functions)
	const targets_path = write_targets(FILE, targets)
	const server_module, client_module, player = playtest_solo(targets, targets_path)

	for name, funct in functions do
		test(name, function()
			local server_funct = server_module.exports[name]
			local client_funct = client_module.exports[name]

			local data = table.create(#funct.data) :: { any }
			for index, datatype in funct.data do
				data[index] = datatype.generate(0)
			end

			local rets = table.create(#funct.ret) :: { any }
			for index, datatype in funct.ret do
				rets[index] = datatype.generate(0)
			end

			local received_data
			local disconnect = server_funct.on(function(...)
				received_data = { ... }
				return unpack(rets)
			end)

			local returned_data
			local invoke_thread = task.spawn(function()
				returned_data = { client_funct.invoke(unpack(data)) }
				return nil :: any
			end)

			client_module.step_replication()
			server_module.step_replication()

			expect(await(invoke_thread, 5)).is(true)
			expect(returned_data).exists()

			disconnect()

			expect(received_data).exists()
			expect(returned_data).exists()
			assert(received_data) -- type checker
			assert(returned_data) -- type checker

			local received_player: PlayerMock = table.remove(received_data, 1) :: any
			expect(received_player).exists()
			expect(received_player.UserId).is(player.UserId)

			for index, expected in data do
				local got = received_data[index]
				expect(got).is(expected)
			end

			for index, expected in rets do
				local got = returned_data[index]
				expect(got).is(expected)
			end
		end)
	end
end
