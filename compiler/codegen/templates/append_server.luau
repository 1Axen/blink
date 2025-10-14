local append_services = require("./append_services")
local globals = require("@lir/build/builders/globals")
local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

local PLAYERS_MAP = globals.players_map.identifier

local EVENT_GLOBALS = globals.events
local RELIABLE_EVENT = EVENT_GLOBALS.reliable.identifier
local UNRELIABLE_EVENT = EVENT_GLOBALS.unreliable.identifier

local SERVICE_GLOBALS = globals.services
local PLAYERS = SERVICE_GLOBALS.players.identifier
local RUN_SERVICE = SERVICE_GLOBALS.run_service.identifier
local REPLICATED_STORAGE = SERVICE_GLOBALS.replicated_storage.identifier

local function append_event(builder: StringBuilder, register: string, name: string)
	local class = register == RELIABLE_EVENT and "RemoteEvent" or "UnreliableRemoteEvent"
	builder:append_lines({
		`local {register} = {REPLICATED_STORAGE}:FindFirstChild("{name}") :: {class}`,
		`if not {register} then`,
		`\tlocal event = Instance.new("{class}")`,
		`\tevent.Name = "{name}"`,
		`\tevent.Parent = {REPLICATED_STORAGE}`,
		`\t{register} = event`,
		"end",
	})
end

local function append_server(builder: StringBuilder, reliable_name: string, unreliable_name: string)
	append_services(builder)
	builder:append_line(`assert({RUN_SERVICE}:IsServer(), "The server module can only be required from the server!")`)
	append_event(builder, RELIABLE_EVENT, reliable_name)
	append_event(builder, UNRELIABLE_EVENT, unreliable_name)

	builder:append_lines({
		"type Save = {",
		"\tbuffers: { buffer },",
		"\tlengths: { number },",
		"\tunknown: { any },",
		"}",
	})

	builder:append_line(`local {PLAYERS_MAP}: \{ [Player]: Save } = \{}`)
	builder:append_lines({
		`{PLAYERS}.PlayerAdded:Connect(function(player)`,
		`\t{PLAYERS_MAP}[player] = \{`,
		"\t\tbuffers = table.create(16) :: { buffer },",
		"\t\tlengths = table.create(16) :: { number },",
		"\t\tunknown = table.create(16) :: { any }",
		"\t}",
		"end)",
		`{PLAYERS}.PlayerRemoving:Connect(function(player)`,
		`\t{PLAYERS_MAP}[player] = nil`,
		"end)",
	})
	builder:append_line("")
end

return append_server
