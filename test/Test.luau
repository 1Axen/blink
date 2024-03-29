local fs = require("@lune/fs")
local task = require("@lune/task")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Compiler = "init"
local Sources = fs.readDir("./Sources")
local Arguments = process.args

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

if stdio.prompt("confirm", "Compile files?") then
    PrettyPrint("blue", "Clearing Network folder...")
    if fs.isDir("../Network") then
        fs.removeDir("../Network")
        fs.writeDir("../Network")
        OkPrint(`Cleared Network folder.`)
    end

    PrettyPrint("blue", "Compiling source files...")
    for _, File in Sources do
        if table.find(Arguments, "nocompile") then
            PrettyPrint("yellow", "nocompile flag was passed, skipping compilation.")
            break
        end

        local AbsolutePath = `../test/Sources/{File}`
        PrettyPrint("cyan", `Compiling: {File}...`, true)
        local Result = process.spawn("lune", {"run", Compiler, AbsolutePath}, {cwd = "../src"})
        if not Result.ok then
            ErrorPrint(`{File} failed to compile!\n{Result.stderr}`)
        else
            OkPrint(`{File} compiled successfully.`)
        end
    end

    PrettyPrint("green", `Successfully compiled {#Sources}/{#Sources} source files!`)
end

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
        ErrorPrint(`Failed "{Name}", expected it to fail, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function FireAndExpect(Name: string, OutgoingEvent: any, IncomingEvent: any, Expect: any)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Result: unknown;
    local IsServerSending = (OutgoingEvent.FireAll ~= nil)
    local IsServerRecieving = (OutgoingEvent.FireAll == nil)

    local Disconnect = IncomingEvent.On(function(First, Second)
        if IsServerRecieving then
            if tostring(First) ~= "Player" then
                ErrorPrint(`Expected argument #1 to {Name} to be Player, got {First} instead.`)
            end

            Result = Second
        else
            Result = First
        end
    end)

    if IsServerSending then
        OutgoingEvent.FireAll(Expect)
    else
        OutgoingEvent.Fire(Expect)
    end

    --> Wait for replication
    task.wait(1 / 30)

    if not CompareValues(Result, Expect) then
        ErrorPrint(`Failed "{Name}", expected to recieve: {Expect}, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function InvokeAndExpect(Name: string, ClientFunction: any, ServerFunction: any, Data: any, Return: boolean?)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local ServerRecieve: unknown;
    ServerFunction.On(function(Player, Recieve: any)
        if tostring(Player) ~= "Player" then
            ErrorPrint(`Expected argument #1 to {Name} to be Player, got {Player} instead.`)
        end

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
        ErrorPrint(`Failed "{Name}", queue expected to recieve: {Expect}, got "{Result}" instead.`)
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function FireAndExpectAll(Name: string, OutgoingEvent: any, IncomingEvent: any, Values: {any})
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Index = 0
    local Results: {unknown} = {}
    local Disconnect = IncomingEvent.On(function(First, Second)
        local Value = (if Second ~= nil then Second else First)

        Index += 1
        Results[Index] = Value
    end)

    local Method = OutgoingEvent.FireAll or OutgoingEvent.Fire
    for Index = 1, table.maxn(Values) do
        Method(Values[Index])
    end
    
    --> Wait for replication
    task.wait(1 / 30)

    for Index, Expect in Values do
        local Result = Results[Index]
        if not CompareValues(Expect, Result) then
            ErrorPrint(`Failed "{Name}", expected to recieve: {Expect} at {Index}, got {Result} instead.`)
        end
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function FireAllAndExpectAll(Name: string, Times: number, Events: {[string]: {Outgoing: any, Incoming: any, Data: {any}}})
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Results: {{unknown}} = {}
    local Disconnects: {() -> ()} = {}

    --> Connect to events
    for Index, Event in Events do
        local EventResults = {}
        Results[Index] = EventResults
        table.insert(Disconnects, Event.Incoming.On(function(...)
            table.insert(EventResults, {...})
        end))
    end

    --> Fire events
    for Index, Event in Events do
        local Outgoing = Event.Outgoing
        local Method = Outgoing.FireAll or Outgoing.Fire
        for Index = 1, Times do
            Method(table.unpack(Event.Data))
        end
    end

    --> Wait for replication
    task.wait(1 / 30)

    for Index, Event in Events do
        local Data = Event.Data
        local EventResults = Results[Index]
        for ResultIndex = 1, Times do
            local Result = EventResults[ResultIndex]
            if not CompareValues(Data, Result) then
                ErrorPrint(`Failed "{Name}" at {Index}, mismatched value at {ResultIndex}.`)
            end
        end
    end

    for _, Disconnect in Disconnects do
        Disconnect()
    end

    OkPrint(`Test "{Name}" passed!`)
end

local function FireAndExpectTuple(Name: string, OutgoingEvent: any, IncomingEvent: any, ...: any)
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Results: {unknown} = {}
    local Disconnect = IncomingEvent.On(function(...)
        Results = {...}
    end)

    local Method = OutgoingEvent.FireAll or OutgoingEvent.Fire
    Method(...)
    
    --> Wait for replication
    task.wait(1 / 30)

    for Index, Expect in {...} do
        local Result = Results[Index]
        if not CompareValues(Expect, Result) then
            ErrorPrint(`Failed "{Name}", mismatched value at {Index}. Expected {Expect}, got {Result} instead.`)
        end
    end

    Disconnect()
    OkPrint(`Test "{Name}" passed!`)
end

local function InvokeAndExpectTuple(Name: string, ClientFunction: any, ServerFunction: any, Data: {any}, Return: {any})
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local ServerRecieve: {unknown};
    ServerFunction.On(function(Player, ...)
        if tostring(Player) ~= "Player" then
            ErrorPrint(`Expected argument #1 to {Name} to be Player, got {Player} instead.`)
        end
        
        ServerRecieve = {...}
        return table.unpack(Return)
    end)
 
    local ClientRecieve: {unknown};
    local Success, Error = pcall(function()
        ClientRecieve = {ClientFunction.Invoke(table.unpack(Data))}
    end)

    if not Success then
        ErrorPrint(`Expected {Name} to succeed but it encountered an error, {Error}.`)
    elseif Success and Return then
        if not CompareValues(ServerRecieve, Data) then
            ErrorPrint(`Expected server {Name} to recieve {Data}, got {ServerRecieve} instead.`)
        end
    
        if not CompareValues(ClientRecieve, Return) then
            ErrorPrint(`Expected client {Name} to recieve {Data}, got {ClientRecieve} instead.`)
        end
    end

    OkPrint(`Test "{Name}" passed!`)
end

local function RunClosure(Name: string, Closure: () -> ())
    PrettyPrint("cyan", `Testing: {Name}...`, true)

    local Success, Error = pcall(Closure)
    if not Success then
        ErrorPrint(Error)
    end

    OkPrint(`Test "{Name}" passed!`)
end

--> Tests
local Instance = setmetatable({
    __typeof = "Instance",
    IsA = function(self)
        return true
    end
}, {
    __tostring = function()
        return "Instance"
    end,
})

local InstanceNeverIsA = setmetatable({
    __typeof = "Instance",
    ClassName = "Never",
    IsA = function(self)
        return false
    end
}, {
    __tostring = function()
        return "Instance (Invalid)"
    end,
})

local Example: Client.Example = {
    Field = 0,
    Enum = "A",
    Nested = {
        Guh = 1,
        Array = table.create(10, 0)
    }
}

PrettyPrint("blue", "Running output tests...")

FireAndExpect("Reliable Server", Server.ReliableServer, Client.ReliableServer, 1)
FireAndExpect("Unreliable Server", Server.UnreliableServer, Client.UnreliableServer, 1)

FireAndExpect("Reliable Client", Client.ReliableClient, Server.ReliableClient, 1)
FireAndExpect("Unreliable Client", Client.UnreliableClient, Server.UnreliableClient, 1)

FireAndExpect("Unknown", Server.Unknown, Client.Unknown, newproxy())

FireAndExpect("Generic", Server.Generic, Client.Generic, {Data = 0, Nested = {Value = 0}})

FireAndExpect("Map", Server.MapEvent, Client.MapEvent, {["string"] = 1})
FireAndExpect("Map Struct", Server.MapStructEvent, Client.MapStructEvent, {Map = {string = 1}})
FireAndExpect("Map Complex", Server.MapComplexEvent, Client.MapComplexEvent, {string = table.create(8, 1)})
FireAndExpect("Map Reference", Server.MapReferenceEvent, Client.MapReferenceEvent, {A = "A"})

FireAndExpect("Struct", Server.Reference, Client.Reference, Example)
FireAndExpect("Array", Server.ArrayPrimitive, Client.ArrayPrimitive, {1, 2, 3, 4, 5, 6, 7, 8})
FireAndExpect("Optional", Server.OptionalPrimitive, Client.OptionalPrimitive, 1)
FireAndExpect("Optional (nil)", Server.OptionalPrimitive, Client.OptionalPrimitive, nil)

FireAndExpect("Instance Any", Server.InstanceAny, Client.InstanceAny, Instance)
FireAndExpect("Instance Type", Server.InstanceOfType, Client.InstanceOfType, Instance)
FireAndExpect("Instance Optional", Server.InstanceOptional, Client.InstanceOptional, Instance)
FireAndExpect("Instance Optional (nil)", Server.InstanceOptional, Client.InstanceOptional, nil)

local Array = table.create(8, Example)
FireAndExpect("Reference", Server.Reference, Client.Reference, Example)
FireAndExpect("Referency Array", Server.ReferenceArray, Client.ReferenceArray, Array)
FireAndExpect("Referency Optional", Server.ReferenceOptional, Client.ReferenceOptional, Example)
FireAndExpect("Referency Optional (nil)", Server.ReferenceOptional, Client.ReferenceOptional, nil)

InvokeAndExpect("Remote Function", Client.RemoteFunction, Server.RemoteFunction, 1, true)
InvokeAndExpect("Remote Function (error)", Client.RemoteFunction, Server.RemoteFunction, 1, false)

QueueAndExpect("Reliable Queue", Server.ReliableServer, Client.ReliableServer, 1)
--QueueAndExpect("Unreliable Queue", Server.UnreliableServer, Client.UnreliableServer, 1)

FireAndFail("Invalid Instance Any", Server.InstanceAny, Client.InstanceAny, true)
FireAndFail("Invalid Instance Type", Server.InstanceOfType, Client.InstanceOfType, InstanceNeverIsA)

FireAndExpectAll("Correct order", Server.ReliableServer, Client.ReliableServer, {1, 2, 3, 4})
FireAndExpectAll("Multiple instances (nil and non nil)", Server.InstanceOptional, Client.InstanceOptional, {nil, Instance, nil, Instance, Instance})

FireAndExpectAll("Many primitive", Server.ReliableServer, Client.ReliableServer, table.create(255, 1))
FireAndExpectAll("Many structs", Server.Reference, Client.Reference, table.create(255, Example))

FireAndExpectTuple("Reliable Tuple", Server.Tuple, Client.Tuple, 255, "A", 65535, Instance, Instance, table.create(8, 0))
FireAndExpectTuple("Unreliable Tuple", Server.TupleUnreliable, Client.TupleUnreliable, 255, "A", 65535, Instance, Instance)
InvokeAndExpectTuple("Function Tuple", Client.TupleFunction, Server.TupleFunction, {255, "A", 65535, Instance, Instance}, {Instance, Instance, 65535, "A", 255})

FireAllAndExpectAll("Many events", 32, {
    Reliable = {
        Data = {0},
        Outgoing = Server.ReliableServer,
        Incoming = Client.ReliableServer
    },
    Unreliable = {
        Data = {0},
        Outgoing = Server.UnreliableServer,
        Incoming = Client.UnreliableServer
    },
    Reference = {
        Data = {Example},
        Outgoing = Server.Reference,
        Incoming = Client.Reference
    },
    ReliableTuple = {
        Data = {255, "A", 65535, Instance, Instance, table.create(8, 0)},
        Outgoing = Server.Tuple,
        Incoming = Client.Tuple
    },
    UnreliableTuple = {
        Data = {255, "A", 65535, Instance, Instance},
        Outgoing = Server.TupleUnreliable,
        Incoming = Client.TupleUnreliable
    }
})

FireAndExpect("TagEnum Join", Server.PlayerEvent, Client.PlayerEvent, {Type = "Join", Name = "Player", UserId = 5})
FireAndExpect("TagEnum Chat", Server.PlayerEvent, Client.PlayerEvent, {Type = "Chat", UserId = 5, Message = "Hello"})
FireAndExpect("TagEnum Leave", Server.PlayerEvent, Client.PlayerEvent, {Type = "Leave", UserId = 5})

RunClosure("Standalone", function()
    local Original = {
        One = 1,
        Two = 2,
        Three = 3,
        Event = {Type = "Join", Name = "JohnDoe", UserId = 1},
        Nested = {
            Four = "ABC",
            Five = "DEF"
        }
    }

    local Serialized = Server.Standalone.Write(Original)
    local Deserialized = Server.Standalone.Read(Serialized)

    assert(CompareTables(Original, Deserialized), "Deserialized doesn't match original")
end)

PrettyPrint("green", `All tests passed successfully!`)

process.exit(0)