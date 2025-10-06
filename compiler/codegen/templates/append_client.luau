local append_services = require("./append_services")
local globals = require("@lir/build/builders/globals")
local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

local EVENT_GLOBALS = globals.events
local RELIABLE_EVENT = EVENT_GLOBALS.reliable.identifier
local UNRELIABLE_EVENT = EVENT_GLOBALS.unreliable.identifier

local SERVICE_GLOBALS = globals.services
local RUN_SERVICE = SERVICE_GLOBALS.run_service.identifier
local REPLICATED_STORAGE = SERVICE_GLOBALS.replicated_storage.identifier

local function append_client(builder: StringBuilder, reliable_event: string, unreliable_event: string)
	append_services(builder)
	builder:append_line(`assert({RUN_SERVICE}:IsClient(), "The client module can only be required from the client!")`)
	builder:append_line(`local {RELIABLE_EVENT} = {REPLICATED_STORAGE}:WaitForChild("{reliable_event}") :: RemoteEvent`)
	builder:append_line(
		`local {UNRELIABLE_EVENT} = {REPLICATED_STORAGE}:WaitForChild("{unreliable_event}") :: UnreliableRemoteEvent`
	)
end

return append_client
