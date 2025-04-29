--!nolint
--!nocheck
local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local RUN_SERVICE = game:GetService("RunService")

if RUN_SERVICE:IsServer() == false then
    error(`The server module can only be required from the server!`)
end

local EVENTS_FOLDER: Folder = REPLICATED_STORAGE:FindFirstChild("BLINK_EVENTS") :: Folder
if EVENTS_FOLDER == nil then
    local folder = Instance.new("Folder")
    folder.Name = "BLINK_EVENTS"
    folder.Parent = REPLICATED_STORAGE
    EVENTS_FOLDER = folder
end

local RELIABLE_EVENT: RemoteEvent = EVENTS_FOLDER:FindFirstChild("BLINK_RELIABLE") :: RemoteEvent
if RELIABLE_EVENT == nil then
    local remote_event = Instance.new("RemoteEvent")
    remote_event.Name = "BLINK_RELIABLE"
    remote_event.Parent = EVENTS_FOLDER
    RELIABLE_EVENT = remote_event
end

local players_map: {[Player]: Save} = {}
PLAYERS.PlayerRemoving:Connect(function(player)
    players_map[player] = nil
end)

local function send_reliable()
    for player, save in players_map do
        if save.cursor == 0 then
            continue
        end

        local trimmed = buffer.create(save.cursor)
        buffer.copy(trimmed, 0, save.buffer, 0, save.cursor)
        RELIABLE_EVENT:FireClient(player, trimmed, save.unknown)

        players_map[player] = nil
    end
end