local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reliable = ReplicatedStorage:WaitForChild("DECLARE_NET_RELIABLE_REMOTE")
local Unreliable = ReplicatedStorage:WaitForChild("DECLARE_NET_UNRELIABLE_REMOTE")

-- SPLIT --
RunService.Heartbeat:Connect(function()
    if SendCursor <= 0 then
        return
    end

    local Buffer = buffer.create(SendCursor)
    buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)
    Reliable:FireServer(Buffer)

    SendCursor = 0
    buffer.fill(SendBuffer, 0, 0)
end)

