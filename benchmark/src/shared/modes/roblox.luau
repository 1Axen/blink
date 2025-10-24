local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Benches = require("../benches")

local Events = {}
local IsServer = RunService:IsServer()

for Name in Benches do
	local Event: RemoteEvent
	if IsServer then
		Event = Instance.new("RemoteEvent")
		Event.Name = Name
		Event.Parent = ReplicatedStorage
	else
		Event = ReplicatedStorage:WaitForChild(Name)
	end

	Events[Name] = Event
end

return Events
