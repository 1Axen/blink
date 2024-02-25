return [[local Invocations = 0

local SendOffset = 0
local SendCursor = 0
local SendBuffer = buffer.create(64)
local SendInstances = {}

local RecieveCursor = 0
local RecieveBuffer = buffer.create(64)

local RecieveInstances = {}
local RecieveInstanceCursor = 0

type BufferSave = {Cursor: number, Buffer: buffer, Instances: {Instance}}

local function Read(Bytes: number)
    local Offset = RecieveCursor
    RecieveCursor += Bytes
    return Offset
end

local function Save(): BufferSave
    return {
        Cursor = SendCursor,
        Buffer = SendBuffer,
        Instances = SendInstances
    }
end

local function Load(Save: BufferSave?)
    if Save then
        SendCursor = Save.Cursor
        SendOffset = Save.Cursor
        SendBuffer = Save.Buffer
        SendInstances = Save.Instances
        return
    end

    SendCursor = 0
    SendOffset = 0
    SendBuffer = buffer.create(64)
    SendInstances = {}
end

local function Invoke()
    if Invocations == 255 then
        Invocations = 0
    end

    local Invocation = Invocations
    Invocations += 1
    return Invocation
end

local function Allocate(Bytes: number)
    local Len = buffer.len(SendBuffer)

    local Size = Len
    local InUse = (SendCursor + Bytes)
    
    if InUse > Size then
        --> Avoid resizing the buffer for every write
        while InUse > Size do
            Size *= 1.5
        end

        local Buffer = buffer.create(Size)
        buffer.copy(Buffer, 0, SendBuffer, 0, Len)
        SendBuffer = Buffer
    end

    SendOffset = SendCursor
    SendCursor += Bytes
    
    return SendOffset
end

local Types = {}
local Calls = table.create(256)

local Events: any = {
    Reliable = table.create(256),
    Unreliable = table.create(256)
}

local Queue: any = {
    Reliable = table.create(256),
    Unreliable = table.create(256)
}

]]