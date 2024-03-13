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

local Recieved = {}
for Name, Data in Benches do
    local BenchRecieved = {}
    Recieved[Name] = BenchRecieved

    local function OnRecieve(Tool: string)
        BenchRecieved[Tool] = 0

		return function(Player, Recieve)
            BenchRecieved[Tool] += 1
            if BenchRecieved[Tool] > 1 then
                return
            end

            if Tool == "bytenet" then
                Player, Recieve = Recieve, Player
            end

			if not CompareValues(Data, Recieve) then
				warn(`Recieved incorrect data with {Tool} for {Name}`)
			else
                print(`> {Tool} passed {Name} validation!`)
            end
		end
    end
    
    for Tool, Events in Modes  do
        local Event = Events[Name]
        local Callback = OnRecieve(Tool)

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

ReplicatedStorage.Shared.GetRecieved.OnServerInvoke = function()
    return Recieved
end

ReplicatedStorage.Shared.Generate.OnServerEvent:Connect(function(Player, JSON)
    local OutputJSON = Instance.new("StringValue")
    OutputJSON.Name = "Result"
    OutputJSON.Value = JSON
    OutputJSON.Parent = game
    print("Generated results")
end)
