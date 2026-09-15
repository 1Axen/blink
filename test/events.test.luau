local compiler = require("@compiler")
local data_model_mock = require("@test/mock/data_model_mock")
local datatypes = require("./datatypes")
local fs = require("@util/fs")
local hir = require("@compiler/hir")
local path = require("@util/path")
local playtest_solo = require("@test/utils/playtest_solo")
local string_builder = require("@util/string_builder")
local tableext = require("@std/tableext")
local write_targets = require("@test/utils/write_targets")

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
	exports: {
		[string]: {
			fire: (...any) -> (),
			on: ((...any) -> ()) -> () -> (),
			iter: () -> () -> (number, ...any),
		},
	},
	step_replication: () -> (),
}

type ServerAPI = {
	exports: {
		[string]: {
			fire: (player: PlayerMock, ...any) -> (),
			fire_all: (...any) -> (),
			fire_list: (list: { PlayerMock }, ...any) -> (),
			fire_except: (player: PlayerMock, ...any) -> (),
			on: ((player: PlayerMock, ...any) -> ()) -> () -> (),
			iter: () -> () -> (number, PlayerMock, ...any),
		},
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

local function shift_down(tbl: { [number]: any, n: number })
	for index = 2, tbl.n do
		local value = tbl[index]
		tbl[index] = nil
		tbl[index - 1] = value
	end
end

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

	const targets = compile_events(events)
	const targets_path = write_targets(FILE, targets)
	const server_module, client_module, player = playtest_solo(targets, targets_path)

	for name, event in events do
		test(name, function()
			local server_event = server_module.exports[name]
			local client_event = client_module.exports[name]

			local payload
			local incoming_event
			local outgoing_event
			local outgoing_module

			local data = table.create(#event.data) :: { any }
			for seed = 1, 2 do
				for index, datatype in event.data do
					data[index] = datatype.generate(seed)
				end

				local from = event.from == "Both" and (seed % 2 == 0 and "Server" or "Client") or event.from
				if from == "Server" then
					payload = { player, unpack(data) }
					incoming_event = client_event :: any
					outgoing_event = server_event :: any
					outgoing_module = server_module
				else
					payload = data
					incoming_event = server_event
					outgoing_event = client_event
					outgoing_module = client_module
				end

				local received_data: { [number]: any, n: number }?
				if event.call == "Polling" then
					outgoing_event.fire(unpack(payload))
					outgoing_module.step_replication()
					received_data = table.pack((incoming_event :: any).iter()())

					for _ in (incoming_event :: any).iter() do
						expect(true).never_is_true()
					end

					expect(received_data[1]).is(1)
					shift_down(received_data)
				else
					local disconnect = incoming_event.on(function(...: any)
						expect(received_data).never_exists()
						received_data = table.pack(...)
					end)
					outgoing_event.fire(unpack(payload))
					outgoing_module.step_replication()
					disconnect()
				end

				expect(received_data).exists()
				assert(received_data) -- type checker

				if incoming_event == server_event then
					local received_player: PlayerMock = received_data[1]
					shift_down(received_data)
					expect(received_player.UserId).is(player.UserId)
				end

				for index, expected_value in data do
					local received_value = received_data[index]
					expect(received_value).is(expected_value)
				end
			end
		end)
	end

	test("batch", function()
		for seed = 1, 2 do
			local outgoing_data_map: { { any } } = {}
			local incoming_data_map: { { [number]: any, n: number } } = {}
			local disconnect_fns_map: { () -> () } = {}
			local event_names = tableext.keys(events)

			for event_index, name in event_names do
				local event = events[name]
				if event.type ~= "Reliable" then
					continue
				end

				local server_event = server_module.exports[name]
				local client_event = client_module.exports[name]

				local outgoing_data = table.create(#event.data)
				for index, datatype in event.data do
					outgoing_data[index] = datatype.generate(seed)
				end

				local payload = outgoing_data
				local incoming_event = server_event
				local outgoing_event = client_event

				local from = event.from == "Both" and (seed % 2 == 0 and "Server" or "Client") or event.from
				if from == "Server" then
					payload = { player, unpack(outgoing_data) }
					incoming_event = client_event
					outgoing_event = server_event :: any
				end

				outgoing_data_map[event_index] = outgoing_data
				outgoing_event.fire(unpack(payload))

				if event.call ~= "Polling" then
					disconnect_fns_map[event_index] = incoming_event.on(function(...: any)
						expect(incoming_data_map[event_index]).never_exists()
						incoming_data_map[event_index] = table.pack(...)
					end)
				end
			end

			server_module.step_replication()
			client_module.step_replication()

			for event_index, name in event_names do
				local event = events[name]
				if event.type ~= "Reliable" then
					continue
				end

				local outgoing_data = outgoing_data_map[event_index]
				expect(outgoing_data).exists()

				local server_event = server_module.exports[name]
				local client_event = client_module.exports[name]

				local from = event.from == "Both" and (seed % 2 == 0 and "Server" or "Client") or event.from
				local incoming_event = server_event
				if from == "Server" then
					incoming_event = client_event :: any
				end

				local incoming_data: { [number]: any, n: number }?
				if event.call == "Polling" then
					incoming_data = table.pack((incoming_event :: any).iter()())
					for _ in (incoming_event :: any).iter() do
						expect(true).never_is_true()
					end

					expect(incoming_data[1]).is(1)
					shift_down(incoming_data)
				else
					disconnect_fns_map[event_index]()
					incoming_data = incoming_data_map[event_index]
				end

				expect(incoming_data).exists()

				if incoming_event == server_event then
					local received_player: PlayerMock = incoming_data[1]
					shift_down(incoming_data)
					expect(received_player.UserId).is(player.UserId)
				end

				for index, expected_value in outgoing_data do
					local received_value = incoming_data[index]
					expect(received_value).is(expected_value)
				end
			end
		end
	end)
end
