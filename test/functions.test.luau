local compiler = require("@compiler")
local data_model_mock = require("@test/mock/data_model_mock")
local datatypes = require("./datatypes")
local environment_mock = require("@test/mock/environment_mock")
local fs = require("@util/fs")
local luau = require("@lute/luau")
local path = require("@util/path")
local string_builder = require("@util/string_builder")
local task = require("@std/task")

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

local function load_server(targets: Targets): (DataModelMock, ServerAPI)
	local luau_contents = targets.server
	local luau_file_path = path.append_file_name(TEMP_PATH, `{FILE}-server`, "luau")
	assert(fs.write_string_to_file(luau_file_path, luau_contents).ok, "luau file write failed")

	local data_model = data_model_mock.create_data_model("Server")
	local environment = table.clone(environment_mock) :: { [any]: any }
	environment.game = data_model
	table.freeze(environment)

	local bytecode = luau.compile(luau_contents)
	local chunkname = path.to_string(luau_file_path)
	return data_model, luau.load(bytecode, chunkname, environment)() :: ServerAPI
end

local function load_client(targets: Targets, server_data_model: DataModelMock): (DataModelMock, PlayerMock, ClientAPI)
	local luau_contents = targets.client
	local luau_file_path = path.append_file_name(TEMP_PATH, `{FILE}-client`, "luau")
	assert(fs.write_string_to_file(luau_file_path, luau_contents).ok, "luau file write failed")

	local client_data_model, player = data_model_mock.connect_player(server_data_model)
	local environment = table.clone(environment_mock) :: { [any]: any }
	environment.game = client_data_model
	table.freeze(environment)

	local server_replicated_storage = server_data_model:GetService("ReplicatedStorage")
	local reliable_event = assert(server_replicated_storage:FindFirstChildOfClass("RemoteEvent"))
	local unreliable_event = assert(server_replicated_storage:FindFirstChildOfClass("UnreliableRemoteEvent"))
	data_model_mock.replicate_instance(reliable_event, server_data_model, client_data_model)
	data_model_mock.replicate_instance(unreliable_event, server_data_model, client_data_model)

	local bytecode = luau.compile(luau_contents)
	local chunkname = path.to_string(luau_file_path)
	return client_data_model, player, luau.load(bytecode, chunkname, environment)() :: ClientAPI
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

	local targets = compile_functions(functions)
	local server, server_functions = load_server(targets)
	local _, player, client_functions = load_client(targets, server)

	for name, funct in functions do
		test(name, function()
			local server_funct = server_functions.exports[name]
			local client_funct = client_functions.exports[name]

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
			local invoke_task = task.create(function()
				returned_data = { client_funct.invoke(unpack(data)) }
				return nil :: any
			end)

			client_functions.step_replication()
			server_functions.step_replication()

			task.await(invoke_task)
			expect(invoke_task.success).is(true)

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
