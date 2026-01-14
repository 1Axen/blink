local compiler = require("@compiler")
local data_model_mock = require("@test/mock/data_model_mock")
local datatypes = require("./datatypes")
local environment_mock = require("@test/mock/environment_mock")
local fs = require("@util/fs")
local hir = require("@compiler/hir")
local luau = require("@lute/luau")
local path = require("@util/path")
local string_builder = require("@util/string_builder")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type Datatype = datatypes.Datatype
type PlayerMock = data_model_mock.PlayerMock
type InstanceMock = data_model_mock.InstanceMock
type DataModelMock = data_model_mock.DataModelMock

type Targets = typeof(compiler.compile_contents(nil :: any, nil :: any))

type From = index<hir.Event, "from">
type Type = index<hir.Event, "type">
type Call = index<hir.Event, "call">
type Data = { Datatype }

type Event = {
	read from: From,
	read type: Type,
	read call: Call,
	read data: Data,
}
type Events = { [string]: Event }

type ClientAPI = {
	[string]: {
		fire: (...any) -> (),
		on: ((...any) -> ()) -> () -> (),
		iter: () -> () -> (number, ...any),
	},
	step_replication: () -> (),
}

type ServerAPI = {
	[string]: {
		fire: (player: PlayerMock, ...any) -> (),
		fire_all: (...any) -> (),
		fire_list: (list: { PlayerMock }, ...any) -> (),
		fire_except: (player: PlayerMock, ...any) -> (),
		on: ((player: PlayerMock, ...any) -> ()) -> () -> (),
		iter: () -> () -> (number, PlayerMock, ...any),
	},
	step_replication: () -> (),
}

local FILE = "events"

local FROM_LIST: { From } = {
	"Server",
	"Client",
	"Both",
}
local TYPE_LIST: { Type } = {
	"Reliable",
	"Unreliable",
}
local CALL_LIST: { Call } = {
	"SingleSync",
	"SingleAsync",
	"ManySync",
	"ManyAsync",
	"Polling",
}

local TEMP_PATH = path.from_string("./temp")

local PRIMITIVES = datatypes.primitives

local function create_event(from: From, type: Type, call: Call, data: Data): Event
	return table.freeze({
		from = from,
		type = type,
		call = call,
		data = data,
	})
end

local function compile_events(events: Events): Targets
	local builder = string_builder.create({})
	builder:append_line("option manual_replication = true")

	for name, event in events do
		builder:append_line(`event {name} = \{`)
		builder:indent()
		builder:append_line(`from: {event.from},`)
		builder:append_line(`type: {event.type},`)
		builder:append_line(`call: {event.call},`)
		builder:append_indent()
		builder:append("data: (")
		for index, datatype in event.data do
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

	local events: Events = {}
	for _, from in FROM_LIST do
		for _, ttype in TYPE_LIST do
			for _, call in CALL_LIST do
				local name = `{from}{ttype}{call}`
				events[`{name}Single`] = create_event(from, ttype, call, { PRIMITIVES.u16 })
				events[`{name}Multiple`] =
					create_event(from, ttype, call, { PRIMITIVES.u8, PRIMITIVES.string, PRIMITIVES.boolean })
				events[`{name}UnknownSingle`] = create_event(from, ttype, call, { datatypes.roblox.unknown })
				events[`{name}UnknownMultiple`] =
					create_event(from, ttype, call, { PRIMITIVES.u8, datatypes.roblox.unknown, PRIMITIVES.string })
				events[`{name}InstanceSingle`] = create_event(from, ttype, call, { datatypes.roblox.instance })
				events[`{name}InstanceMultiple`] =
					create_event(from, ttype, call, { PRIMITIVES.u8, datatypes.roblox.instance, PRIMITIVES.string })
				events[`{name}StreamedInstanceSingle`] =
					create_event(from, ttype, call, { datatypes.roblox.streamed_instance })
				events[`{name}StreamedInstanceMultiple`] = create_event(
					from,
					ttype,
					call,
					{ PRIMITIVES.u8, datatypes.roblox.streamed_instance, PRIMITIVES.string }
				)
			end
		end
	end

	local targets = compile_events(events)
	local server, server_events = load_server(targets)
	local _, player, client_events = load_client(targets, server)

	for name, event in events do
		test(name, function()
			local server_event = server_events[name]
			local client_event = client_events[name]

			local data = table.create(#event.data) :: { any }
			for index, datatype in event.data do
				data[index] = datatype.generate(0)
			end

			local sender_api
			local sender_event
			local receiver_event
			local sender_payload

			if event.from == "Server" then
				sender_api = server_events
				receiver_event = client_event :: any
				sender_event = server_event :: any
				sender_payload = { player, unpack(data) }
			else
				sender_api = client_events
				receiver_event = server_event
				sender_event = client_event
				sender_payload = data
			end

			local received_data: { any }?
			if event.call == "Polling" then
				sender_event.fire(unpack(sender_payload))
				sender_api.step_replication()
				received_data = { (receiver_event :: any).iter()() }
				expect(table.remove(received_data, 1)).is(1)
			else
				local disconnect = receiver_event.on(function(...: any)
					expect(received_data).never_exists()
					received_data = { ... }
				end)
				sender_event.fire(unpack(sender_payload))
				sender_api.step_replication()
				disconnect()
			end

			expect(received_data).exists()
			assert(received_data) -- type checker

			if receiver_event == server_event then
				local received_player: PlayerMock = table.remove(received_data, 1) :: any
				expect(received_player.UserId).is(player.UserId)
			end

			for index, expected_value in data do
				local received_value = received_data[index]
				expect(received_value).is(expected_value)
			end
		end)
	end
end
