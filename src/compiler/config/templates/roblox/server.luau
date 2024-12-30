--!nolint
--!nocheck
local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local RUN_SERVICE = game:GetService("RunService")

if RUN_SERVICE:IsServer() == false then
    error(`The server module can only be required from the server!`)
end

local PLAYERS_MAP: {[Player]: Save} = {}

local RELIABLE_EVENT: RemoteEvent = REPLICATED_STORAGE:FindFirstChild("BLINK_RELIABLE") :: RemoteEvent
if RELIABLE_EVENT == nil then
    local RemoteEvent = Instance.new("RemoteEvent")
    RemoteEvent.Name = "BLINK_RELIABLE"
    RemoteEvent.Parent = REPLICATED_STORAGE
    RELIABLE_EVENT = RemoteEvent
end

local UNRELIABLE_EVENT: UnreliableRemoteEvent = REPLICATED_STORAGE:FindFirstChild("BLINK_UNRELIABLE") :: UnreliableRemoteEvent
if UNRELIABLE_EVENT == nil then
    local UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
    UnreliableRemoteEvent.Name = "BLINK_UNRELIABLE"
    UnreliableRemoteEvent.Parent = REPLICATED_STORAGE
    UNRELIABLE_EVENT = UnreliableRemoteEvent
end

PLAYERS.PlayerRemoving:Connect(function(player)
    PLAYERS_MAP[player] = nil
end)

local function send_events()
    for player, save in PLAYERS_MAP do
        if save.cursor == 0 then
            continue
        end

        local trimmed = buffer.create(save.cursor)
        buffer.copy(trimmed, 0, save.buffer, 0, save.cursor)
        RELIABLE_EVENT:FireClient(player, trimmed, save.unknown)

        PLAYERS_MAP[player] = nil
    end
end