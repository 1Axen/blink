--!strict

local types = require("@lir/types")

type Global<T = any> = types.Global<T>

local function global<T>(identifier: string): Global<T>
	return {
		__readable = nil :: any,
		__writeable = nil :: any,

		type = "global",
		identifier = identifier,
	}
end

return table.freeze({
	create = global,
	templates = global("templates"),
	types_map = global("types"),
	queues_map = global("queues"),
	players_map = global<<{ [Player]: any }>>("players_map"),
	connections_map = global("connections"),
	invocations_map = global("invocations"),
	invocations_bitset = global<<number>>("invocations_bitset"),

	services = {
		players = global<<Players>>("PLAYERS"),
		run_service = global<<RunService>>("RUN_SERVICE"),
		replicated_storage = global<<ReplicatedStorage>>("REPLICATED_STORAGE"),
	},

	incoming = {
		buffer = global<<buffer>>("in_buffer"),
		cursor = global<<number>>("in_cursor"),
		unknown = global<<{ any }>>("in_unknown"),
		unknown_cursor = global<<number>>("in_unknown_cursor"),
	},

	outgoing = {
		buffer = global<<buffer>>("out_buffer"),
		cursor = global<<number>>("out_cursor"),
		length = global<<number>>("out_length"),
		unknown = global<<{ any }>>("out_unknown"),
	},

	events = {
		reliable = global<<RemoteEvent>>("RELIABLE_EVENT"),
		unreliable = global<<RemoteEvent>>("UNRELIABLE_EVENT"),
	},
})
