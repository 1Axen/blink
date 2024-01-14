local fs = require("@lune/fs")
local task = require("@lune/task")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Compiler = "init"
local Sources = fs.readDir("./Sources")

local function OkPrint(Message: string)
    stdio.write("[")
    stdio.write(stdio.color("green") .. "OK")
    stdio.write(stdio.color("reset"))
    stdio.write(`] {Message}\n`)
end

local function ErrorPrint(Message: string)
    stdio.write("[")
    stdio.write(stdio.color("red") .. "ERROR")
    stdio.write(stdio.color("reset"))
    stdio.write(`] {Message}\n`)
    process.exit(20)
end

local function PrettyPrint(Color: stdio.Color, Message: string)
    stdio.write(stdio.color(Color))
    stdio.write(`{Message}\n`)
    stdio.write(stdio.color("reset"))
end

PrettyPrint("blue", "Compiling source files...")
for _, File in Sources do
    local AbsolutePath = `C:/Users/User/Documents/GitHub/Blink/test/Sources/{File}`
    local Result = process.spawn("lune", {Compiler, AbsolutePath}, {cwd = "C:/Users/User/Documents/GitHub/Blink/src/"})
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

local function FireAndExpect(Name: string, OutgoingEvent: any, IncomingEvent: any, Expect: any)
    local Result: unknown;
    IncomingEvent.On(function(First, Second)
        Result = if (Second ~= nil) then Second else First
    end)

    if OutgoingEvent.FireAll then
        OutgoingEvent.FireAll(Expect)
    else
        OutgoingEvent.Fire(Expect)
    end

    --> Wait for replication
    task.wait(1 / 30)

    local AreEqual = (Result == Expect)
    if type(Expect) == "table" then
        AreEqual = CompareTables(Expect, Result)
    end

    if not AreEqual then
        ErrorPrint(`Fired "{Name}" and expected to recieve: {Expect}, got "{Result}" instead.`)
    end

    OkPrint(`Event "{Name}" passed!`)
end

local function InvokeAndExpect(Name: string, ClientFunction: any, ServerFunction: any, Data: any, Return: boolean?)
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
    
        if Result ~= Data then
            ErrorPrint(`Expected client {Name} to recieve {Data}, got {Result} instead.`)
        end
    end

    OkPrint(`Function "{Name}" passed!`)
end

--> Tests
PrettyPrint("blue", "Running output tests...")

FireAndExpect("ClientToServer", Client.ClientToServerEvent, Server.ClientToServerEvent, 255)
FireAndExpect("ClientToServerUnreliable", Client.ClientToServerUnreliableEvent, Server.ClientToServerUnreliableEvent, 255)

FireAndExpect("SeverToClient", Server.SeverToClientEvent, Client.SeverToClientEvent, 255)
FireAndExpect("ServerToClientUnreliable", Server.ServerToClientUnreliableEvent, Client.ServerToClientUnreliableEvent, 255)

InvokeAndExpect("RemoteFunction", Client.RemoteFunction, Server.RemoteFunction, 5, true)
InvokeAndExpect("RemoteFunction_Fail", Client.RemoteFunction, Server.RemoteFunction, 5, false)

local Example: Client.Example = {
    Field = 0,
    Enum = "A",
    Nested = {
        Guh = 1,
        Array = table.create(10, 0)
    }
}

FireAndExpect("StructEvent", Server.StructEvent, Client.StructEvent, Example)

PrettyPrint("green", `All tests passed successfully!`)

process.exit(0)