local task = require("@lune/task")

local Player = newproxy()

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

local Buffer = {}

type Buffer = {
    Size: number,
    Memory: {number},
}

local function BufferReadString(Buffer: Buffer, Offset: number, Count: number): string
    local String = ""
    local Memory = Buffer.Memory

    for Index = 0, (Count - 1) do
        local Position = (Offset + Index)
        local Byte = Memory[Position]
        if not Byte then
            error("buffer access out of bounds")
        end

        local Char = string.char(Byte)
            String ..= Char
    end
    
    return String
end

local function BufferReadNumber(Buffer: Buffer, Offset: number, Count: number): number
    local Number = 0
    local Memory = Buffer.Memory

    for Index = 0, (Count - 1) do
        local Position = (Offset + Index)
        local Byte = Memory[Position]
        if not Byte then
            error(`buffer access out of bounds at {Position}`)
        end

        Number += bit32.lshift(Byte, Index * 8)
    end
    
    return Number
end

local function BufferWrite(Buffer: Buffer, Offset: number, Count: number, Value: number | string)
    local Memory = Buffer.Memory
    for Index = 0, (Count - 1) do
        local Position = (Offset + Index)
        if Position >= Buffer.Size or Position < 0 then
            error(`buffer access out of bounds at {Position}`)
        end

        if type(Value) == "string" then
            local Char = string.sub(Value, Index + 1, Index + 1)
            local Byte = string.byte(Char)
            Memory[Position] = Byte
        else
            local Number = bit32.extract(Value, Index * 8, 8)
            Memory[Position] = Number
        end

        --print(`[BUFFER] Wrote {Memory[Position]} at {Position} to buffer.`)
    end
end

function Buffer.create(Size: number): Buffer
    local Memory = table.create(Size, 0)
    Memory[0] = 0

    return {
        Size = Size,
        Memory = Memory,
    }
end

function Buffer.len(Buffer: Buffer): number
    return Buffer.Size
end

local Sizes = {8, 16, 32}
for _, Size in Sizes do
    local Bytes = (Size / 8)
    Buffer[`readu{Size}`] = function(Buffer: Buffer, Offset: number): number
        return BufferReadNumber(Buffer, Offset, Bytes)
    end

    Buffer[`readi{Size}`] = function(Buffer: Buffer, Offset: number): number
        return BufferReadNumber(Buffer, Offset, 1)
    end

    Buffer[`writeu{Size}`] = function(Buffer: Buffer, Offset: number, Value: number)
        BufferWrite(Buffer, Offset, Bytes, Value)
    end

    Buffer[`writei{Size}`] = function(Buffer: Buffer, Offset: number, Value: number)
        BufferWrite(Buffer, Offset, Bytes, Value)
    end
end

function Buffer.readf32(Buffer: Buffer, Offset: number): number
    return BufferReadNumber(Buffer, Offset, 4)
end

function Buffer.writef32(Buffer: Buffer, Offset: number, Value: number)
    BufferWrite(Buffer, Offset, 4, Value)
end

function Buffer.readf64(Buffer: Buffer, Offset: number): number
    return BufferReadNumber(Buffer, Offset, 8)
end

function Buffer.writef64(Buffer: Buffer, Offset: number, Value: number)
    BufferWrite(Buffer, Offset, 8, Value)
end

function Buffer.readstring(Buffer: Buffer, Offset: number, Count: number): string
    return BufferReadString(Buffer, Offset, Count)
end

function Buffer.writestring(Buffer: Buffer, Offset: number, Value: string, Count: number?)
    BufferWrite(Buffer, Offset, Count or #Value, Value)
end

function Buffer.copy(Target: Buffer, TargetOffset: number, Source: Buffer, SourceOffset: number, Count: number?)
    --print(`[BUFFER] Copied buffer`)
    for Index = 0, ((Count or Source.Size - SourceOffset) - 1) do
        local SourcePosition = (SourceOffset + Index)
        local TargetPosition = (TargetOffset + Index)

        if SourcePosition >= Source.Size or SourcePosition < 0 then
            error(`buffer access out of bounds at {SourcePosition}`)
        end

        if TargetPosition >= Target.Size or TargetPosition < 0 then
            error(`buffer access out of bounds at {TargetPosition}`)
        end

        Target.Memory[TargetPosition] = Source.Memory[SourcePosition]
    end
end

function Buffer.fill(Buffer: Buffer, Offset: number, Value: number, Count: number?)
    --print(`[BUFFER] Filled buffer with {Value}`)
    for Index = 0, ((Count or Buffer.Size - Offset) - 1) do
        local Position = (Offset + Index)
        if Position >= Buffer.Size or Position < 0 then
            error(`buffer access out of bounds at {Position}`)
        end

        Buffer.Memory[Position] = Value
    end
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
        buffer = Buffer,

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

