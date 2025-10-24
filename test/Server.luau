local Shared = require("./Shared")

local Signal = Shared.Signal
local ServerEnviornment = Shared.GetEnvironment()

local function Clone(Source: buffer): buffer
	local Size = buffer.len(Source)
	local Target = buffer.create(Size)
	buffer.copy(Target, 0, Source, 0, Size)
	return Target
end

local function Fire(Reliable: boolean, ...)
	local Arguments = { ... }
	local Buffer = #Arguments == 2 and Arguments[1] or Arguments[2]
	local Instances = Arguments[#Arguments]

	Buffer = Clone(Buffer)
	Instances = table.clone(Instances)

	Shared.Bridge:Fire("Server", Reliable and "BLINK_RELIABLE_REMOTE" or "BLINK_UNRELIABLE_REMOTE", Buffer, Instances)
end

ServerEnviornment.Instances.BLINK_RELIABLE_REMOTE = {
	FireClient = function(self, Player, ...)
		Fire(true, ...)
	end,
	FireAllClients = function(self, ...)
		Fire(true, ...)
	end,
	OnServerEvent = Signal.new(),
}

ServerEnviornment.Instances.BLINK_UNRELIABLE_REMOTE = {
	FireClient = function(Player, ...)
		Fire(false, ...)
	end,
	FireAllClients = function(self, ...)
		Fire(false, ...)
	end,
	OnServerEvent = Signal.new(),
}

Shared.Bridge:Connect(function(From: string, Remote: string, Buffer: buffer, Instances: { Instance })
	if From == "Server" then
		return
	end

	ServerEnviornment.Instances[Remote].OnServerEvent:Fire(Shared.Player, Buffer, Instances)
end)

return ServerEnviornment
