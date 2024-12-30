--!nolint
--!nocheck
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local RUN_SERVICE = game:GetService("RunService")

if RUN_SERVICE:IsClient() == false then
    error(`The client module can only be required from the client!`)
end

local RELIABLE_EVENT: RemoteEvent = REPLICATED_STORAGE:WaitForChild("BLINK_RELIABLE") :: RemoteEvent
local UNRELIABLE_EVENT: UnreliableRemoteEvent = REPLICATED_STORAGE:WaitForChild("BLINK_UNRELIABLE") :: UnreliableRemoteEvent

local function send_events()
    if out_cursor == 0 then
        return
    end

    local trimmed = buffer.create(out_cursor)
    buffer.copy(trimmed, 0, out_buffer, 0, out_cursor)
    RELIABLE_EVENT:FireServer(out_buffer, out_unknown)

    reset_out()
end