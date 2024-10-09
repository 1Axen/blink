local Shared = require("Shared")

local Signal = Shared.Signal
local ClientEnviornment = Shared.GetEnvironment()

local function Clone(Source: buffer): buffer
    local Size = buffer.len(Source)
    local Target = buffer.create(Size)
    buffer.copy(Target, 0, Source, 0, Size)
    return Target
end

local function Fire(Reliable: boolean, ...)
    local Arguments = {...}
    local Buffer = #Arguments == 2 and Arguments[1] or Arguments[2]
    local Instances = Arguments[#Arguments]

    Buffer = Clone(Buffer)
    Instances = table.clone(Instances)

    Shared.Bridge:Fire("Client", Reliable and "BLINK_RELIABLE_REMOTE" or "BLINK_UNRELIABLE_REMOTE", Buffer, Instances)
end

ClientEnviornment.Instances.BLINK_RELIABLE_REMOTE = {
    FireServer = function(self, ...)
        Fire(true, ...)
    end,
    OnClientEvent = Signal.new()
}

ClientEnviornment.Instances.BLINK_UNRELIABLE_REMOTE = {
    FireServer = function(self, ...)
        Fire(false, ...)
    end,
    OnClientEvent = Signal.new()
}

Shared.Bridge:Connect(function(From: string, Remote: string, Buffer: buffer, Instances: {Instance})
    if From == "Client" then
        return
    end

    ClientEnviornment.Instances[Remote].OnClientEvent:Fire(Buffer, Instances)
end)

return ClientEnviornment