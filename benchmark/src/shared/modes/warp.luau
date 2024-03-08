local RunService = game:GetService("RunService")

local Warp = require("../../../packages/warp")
local Benches = require("../benches")

local Events = {}
local Method = RunService:IsServer() and "Server" or "Client"

for Name in Benches do
    Events[Name] = Warp[Method](Name, {
        interval = 0,
        maxEntrance = math.huge,
    })
end

return Events
