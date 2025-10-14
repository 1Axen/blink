local globals = require("@lir/build/builders/globals")
local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

local SERVICE_GLOBALS = globals.services

local function append_services(builder: StringBuilder)
	builder:append_line(`local {SERVICE_GLOBALS.players.identifier} = game:GetService("Players")`)
	builder:append_line(`local {SERVICE_GLOBALS.replicated_storage.identifier} = game:GetService("ReplicatedStorage")`)
	builder:append_line(`local {SERVICE_GLOBALS.run_service.identifier} = game:GetService("RunService")`)
	builder:append_line("")
end

return append_services
