local task = require("@lune/task")

local Player = newproxy(true)
local Metatable = getmetatable(Player)
Metatable.__tostring = function()
    return "Player"
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({
        Connections = {}
    }, Signal)
end

function Signal:Fire(...)
    for _, Function in self.Connections do
        task.spawn(Function, ...)
    end
end

function Signal:Connect(Callback: (...unknown) -> (unknown))
    local Key = tostring(os.clock())
    self.Connections[Key] = Callback
    return {
        Disconnect = function()
            self.Connections[Key] = nil
        end
    }
end

--> Game emulation enviornment
local function GetEnviornment()
    local Instances = {}
    local Services = {
        Players = {
            PlayerRemoving = Signal.new(),
            GetPlayers = function(self)
                return {Player}
            end
        },
        
        ReplicatedStorage = {
            Instances = Instances,
            FindFirstChild = function(self, Name: string)
                assert(Instances[Name], `Attempted to find child: "{Name}", but it was not defined.`)
                return Instances[Name]
            end
        },

        RunService = {
            Heartbeat = Signal.new(),
            IsClient = function(self)
                return true
            end,
            IsServer = function(self)
                return true
            end,
        }
    }

    Services.ReplicatedStorage.WaitForChild = Services.ReplicatedStorage.FindFirstChild

    task.spawn(function()
        while true do
            local DeltaTime = task.wait(1/60)
            for Index, Function in Services.RunService.Heartbeat.Connections do
                Function(DeltaTime)
            end
        end
    end)

    return {
        game = {
            GetService = function(self, Service: string)
                assert(Services[Service], `Attempted to get service: "{Service}", but it was not defined.`)
                return Services[Service]
            end
        },

        Services = Services,
        Instances = Instances
    }
end

return {
    Signal = Signal,
    Player = Player,
    Bridge = Signal.new(),
    GetEnviornment = GetEnviornment
}

