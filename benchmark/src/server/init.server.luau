local Zap = require(game.ReplicatedStorage.zap.Server)
local Blink = require(game.ReplicatedStorage.blink.Server)
local Benches = require(game.ReplicatedStorage.benches)

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

for Name, Data in Benches do
    local function OnRecieve(Player, Recieve)
        if not CompareValues(Data, Recieve) then
            warn(`Recieved incorrect data for {Name}`)
        end
    end
    
    Blink[Name].On(OnRecieve)
    Zap[Name].SetCallback(OnRecieve)
end


