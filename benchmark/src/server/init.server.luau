local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Modes = require("../shared/modes")
local Benches = require("../shared/benches")

function CompareTables(a, b)
    if a == b then 
        return true 
    end

    if type(a) ~= type(b) then 
        return false 
    end

    if type(a) ~= "table" then 
        return false 
    end

    local Keys = {}
    for Key, Value in a do
        local SecondaryValue = b[Key]
        if SecondaryValue == nil or not CompareTables(Value, SecondaryValue) then
            return false
        end
        Keys[Key] = true
    end

    for Key, _ in b do
        if not Keys[Key] then 
            return false 
        end
    end

    return true
end

local function CompareValues(a, b): boolean
    if type(a) == "table" or type(b) == "table" then
        return CompareTables(a, b)
    end
    return (a == b)
end

local Received = {}
for Name, Data in Benches do
    local BenchReceived = {}
    Received[Name] = BenchReceived

    local function OnReceive(Tool: string)
        BenchReceived[Tool] = 0

		return function(Player, Receive)
            BenchReceived[Tool] += 1
            if BenchReceived[Tool] > 1 then
                return
            end

            if Tool == "bytenet" then
                Player, Receive = Receive, Player
            end

			if not CompareValues(Data, Receive) then
				warn(`Received incorrect data with {Tool} for {Name}`)
			else
                print(`> {Tool} passed {Name} validation!`)
            end
		end
    end
    
    for Tool, Events in Modes  do
        local Event = Events[Name]
        local Callback = OnReceive(Tool)

        if Tool == "warp" then
            Event:Connect(Callback)
            continue
        elseif Tool == "roblox" then
            Event.OnServerEvent:Connect(Callback)
            continue
        end

        local Method = Event.On or Event.SetCallback or Event.listen
        Method(Callback)
    end
end

ReplicatedStorage.Shared.GetReceived.OnServerInvoke = function()
    return Received
end

ReplicatedStorage.Shared.Generate.OnServerEvent:Connect(function(Player, JSON)
    local OutputJSON = Instance.new("StringValue")
    OutputJSON.Name = "Result"
    OutputJSON.Value = JSON
    OutputJSON.Parent = game
    print("Generated results")
end)
