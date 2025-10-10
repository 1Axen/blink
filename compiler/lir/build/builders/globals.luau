--!strict

local lir = require("@lir/types")

type Global<T = any> = lir.Global<T>

local function global<T>(identifier: string): Global<T>
	return {
		__phantom_type = nil :: any,

		type = "global",
		identifier = identifier,
	}
end

return table.freeze({
	create = global,
	types_map = global("types"),
	players_map = global("players_map"),

	services = {
		players = global("PLAYERS") :: Global<Players>,
		run_service = global("RUN_SERVICE") :: Global<RunService>,
		replicated_storage = global("REPLICATED_STORAGE") :: Global<ReplicatedStorage>,
	},

	incoming = {
		buffer = global("in_buffer") :: Global<buffer>,
		cursor = global("in_cursor") :: Global<number>,
		unknown = global("in_unknown") :: Global<{ unknown }>,
		unknown_cursor = global("in_unknown_cursor") :: Global<number>,
	},

	outgoing = {
		buffer = global("out_buffer") :: Global<buffer>,
		cursor = global("out_cursor") :: Global<number>,
		length = global("out_length") :: Global<number>,
		unknown = global("out_unknown") :: Global<{ unknown }>,
	},

	events = {
		reliable = global("RELIABLE_EVENT") :: Global<RemoteEvent>,
		unreliable = global("UNRELIABLE_EVENT") :: Global<RemoteEvent>,
	},
})
