local fs = require("@lune/fs")
local task = require("@lune/task")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Compiler = "init"
local Sources = fs.readDir("./Sources")

local function OkPrint(Message: string)
    stdio.write(`\r[{stdio.color("green")}OK{stdio.color("reset")}] {Message}\n`)
end

local function ErrorPrint(Message: string)
    stdio.write(`\r[{stdio.color("red")}ERROR{stdio.color("reset")}] {Message}\n`)
    process.exit(20)
end

local function PrettyPrint(Color: stdio.Color, Message: string, DontReturn: boolean?)
    stdio.write(`{stdio.color(Color)}{Message}{not DontReturn and "\n" or ""}{stdio.color("reset")}`)
end

PrettyPrint("blue", "Compiling source files...")
for _, File in Sources do
    local AbsolutePath = `C:/Users/User/Documents/GitHub/Blink/test/Sources/{File}`
    PrettyPrint("cyan", `Compiling: {File}...`, true)
    local Result = process.spawn("lune", {"run", Compiler, AbsolutePath}, {cwd = "C:/Users/User/Documents/GitHub/Blink/src/"})
    if not Result.ok then
        ErrorPrint(`{File} failed to compile!\n{Result.stderr}`)
    else
        OkPrint(`{File} compiled successfully.`)
    end
end

PrettyPrint("green", `Successfully compiled {#Sources}/{#Sources} source files!`)

local Shared = require("Shared")
local ClientEnviornment = require("Client")
local ServerEnviornment = require("Server")

_G.client = {
    game = ClientEnviornment.game,
    buffer = ClientEnviornment.buffer
}

_G.server = {
    game = ServerEnviornment.game,
    buffer = ServerEnviornment.buffer
}

local Client = require("../Network/Client")
local Server = require("../Network/Server")

--> Helper functions
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

local function FireAndFail(Name: string, OutgoingEvent: any, IncomingEvent: any, Data: any)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Result: unknown;
    local Disconnect = IncomingEvent.On(function(First, Second)
        Result = if (Second ~= nil) then Second else First
    end)

    local Success, Error = pcall(function()
        if OutgoingEvent.FireAll then
            OutgoingEvent.FireAll(Data)
        else
            OutgoingEvent.Fire(Data)
        end
    end)

    if not Success then
        OkPrint(`Event "{Name}" passed!`)
        return
    end

    --> Wait for replication
    task.wait(1 / 30)

    if Result ~= nil then
        ErrorPrint(`Fired "{Name}" and expected it to fail, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function FireAndExpect(Name: string, OutgoingEvent: any, IncomingEvent: any, Expect: any)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Result: unknown;
    local Disconnect = IncomingEvent.On(function(First, Second)
        Result = if (Second ~= nil) then Second else First
    end)

    if OutgoingEvent.FireAll then
        OutgoingEvent.FireAll(Expect)
    else
        OutgoingEvent.Fire(Expect)
    end

    --> Wait for replication
    task.wait(1 / 30)

    if not CompareValues(Result, Expect) then
        ErrorPrint(`Fired "{Name}" and expected to recieve: {Expect}, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function InvokeAndExpect(Name: string, ClientFunction: any, ServerFunction: any, Data: any, Return: boolean?)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local ServerRecieve: unknown;
    ServerFunction.On(function(Player, Recieve: any)
        ServerRecieve = Recieve
        if not Return then
            error("Expects fail")
        end

        return Recieve
    end)

    local Success, Result = pcall(function()
        return ClientFunction.Invoke(Data)
    end)

    if not Return and Success then
        ErrorPrint(`Expected {Name} to encounter an error but it succeeded.`)
    elseif not Success and Return then
        ErrorPrint(`Expected {Name} to succeed but it encountered an error, {Result}.`)
    elseif Success and Return then
        if ServerRecieve ~= Data then
            ErrorPrint(`Expected server {Name} to recieve {Data}, got {ServerRecieve} instead.`)
        end
    
        if not CompareValues(Result, Data) then
            ErrorPrint(`Expected client {Name} to recieve {Data}, got {Result} instead.`)
        end
    end

    OkPrint(`Test "{Name}" passed!`)
end

local function QueueAndExpect(Name: string, OutgoingEvent: any, IncomingEvent: any, Expect: any)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Result: unknown;
    if OutgoingEvent.FireAll then
        OutgoingEvent.FireAll(Expect)
    else
        OutgoingEvent.Fire(Expect)
    end

    --> Let it sit in queue
    task.wait(0.5)

    local Disconnect = IncomingEvent.On(function(First, Second)
        Result = if (Second ~= nil) then Second else First
    end)

    --> Wait for queue to empty
    task.wait(1 / 30)

    if not CompareValues(Result, Expect) then
        ErrorPrint(`Fired "{Name}" with queue and expected to recieve: {Expect}, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

--> Tests
PrettyPrint("blue", "Running output tests...")

FireAndExpect("ClientToServer", Client.ClientToServerEvent, Server.ClientToServerEvent, 255)
FireAndExpect("ClientToServerUnreliable", Client.ClientToServerUnreliableEvent, Server.ClientToServerUnreliableEvent, 255)

FireAndExpect("SeverToClient", Server.SeverToClientEvent, Client.SeverToClientEvent, 255)
FireAndExpect("ServerToClientUnreliable", Server.ServerToClientUnreliableEvent, Client.ServerToClientUnreliableEvent, 255)

InvokeAndExpect("RemoteFunction", Client.RemoteFunction, Server.RemoteFunction, 5, true)
InvokeAndExpect("RemoteFunction_Fail", Client.RemoteFunction, Server.RemoteFunction, 5, false)

local Instance = {
    __typeof = "Instance",
    IsA = function(self)
        return true
    end
}

local InstanceNeverIsA = {
    __typeof = "Instance",
    IsA = function(self)
        return false
    end
}

local Example: Client.Example = {
    Field = 0,
    Enum = "A",
    Nested = {
        Guh = 1,
        Array = table.create(10, 0)
    }
}

FireAndExpect("StructEvent", Server.StructEvent, Client.StructEvent, Example)

FireAndExpect("ChantReliable", Server.Chant, Client.Chant, Instance)
FireAndExpect("ChantUnreliable", Server.UnreliableChant, Client.UnreliableChant, Instance)

FireAndExpect("Streamed", Server.StreamedInstance, Client.StreamedInstance, Instance)
FireAndExpect("Not streamed", Server.StreamedInstance, Client.StreamedInstance, nil)

FireAndFail("Invalid type", Server.SeverToClientEvent, Client.SeverToClientEvent, true)
FireAndFail("Invalid instance class", Server.StreamedInstance, Client.StreamedInstance, InstanceNeverIsA)

QueueAndExpect("Reliable Queue", Server.QueueReliable, Client.QueueReliable, 1)
QueueAndExpect("Unreliable Queue", Server.QueueUnreliable, Client.QueueUnreliable, 1)

FireAndExpect("Optional reference to be nil", Server.OptionalReference, Client.OptionalReference, nil)
FireAndExpect("Optional reference to be value", Server.OptionalReference, Client.OptionalReference, Example)

PrettyPrint("green", `All tests passed successfully!`)

process.exit(0)