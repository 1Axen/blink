--!native
--!optimize 2
--!strict

local fs = require("@lune/fs")

local Parser = require("../Parser")
local Builder = require("../Modules/Builder")
local Prefabs = require("./Prefabs")

local Sources = {
	Base = if _G.BUNDLED then (require("Base") :: any) else fs.readFile("./Templates/Base.txt"),
	Client = string.split(if _G.BUNDLED then (require("Client") :: any) else fs.readFile("./Templates/Client.txt"), "-- SPLIT --"),
	Server = string.split(if _G.BUNDLED then (require("Server") :: any) else fs.readFile("./Templates/Server.txt"), "-- SPLIT --"),
}

local DIRECTIVES = "--!strict\n--!native\n--!optimize 2\n\n"
local OPTIONAL = `if buffer.readu8(RecieveBuffer, Read(1)) == 1 then`
local YIELD_BODY = {
	"Calls[InvocationIdentifier] = coroutine.running()",
	"local Success, Return = coroutine.yield()",
	"if not Success then error(Return) end",
	"return Return"
}
local EVENT_BODY =
	"\tRecieveCursor = 0\n\tRecieveBuffer = Buffer\n\tRecieveInstances = Instances\n\tRecieveInstanceCursor = 0\n\tlocal Size = buffer.len(RecieveBuffer)\n\twhile RecieveCursor < Size do\n\t\tlocal Index = buffer.readu8(RecieveBuffer, Read(1))"

local SAVE_BODY = {
	Header = "local Buffer, Size, Instances = SendBuffer, SendCursor, SendInstances",
	Body = {
		"Load(PlayersMap[Player])",
		"buffer.copy(SendBuffer, Allocate(Size), Buffer, 0, Size)",
		"table.move(Instances, 1, #Instances, #SendInstances + 1, SendInstances)",
		"PlayersMap[Player] = Save()"
	}
}

local AUTOMATIC_REPLICATION = {
	Server = {
		"RunService.Heartbeat:Connect(StepReplication)"
	},
	Client = {
		"local Elapsed = 0",
		"RunService.Heartbeat:Connect(function(DeltaTime: number)",
		"\tElapsed += DeltaTime",
		"\tif Elapsed < (1 / 61) then return end",
		"\tElapsed -= (1 / 61)",
		"\tStepReplication()",
		"end)",
	}
}

local DEBUUG_GLOBALS = "local og_typeof = typeof\nlocal typeof = function(a: any)\n\tif type(a) == \"table\" then return a.__typeof or \"table\" end\n\treturn og_typeof(a)\nend\nlocal task = require(\"@lune/task\")\nlocal game = _G.%s.game\n\n"

local Types = Builder.new()
local LuauTypes = Builder.new()
local Imports = Builder.new()
local Return = Builder.new()
local ReliableEvents = Builder.new()
local UnreliableEvents = Builder.new()

local Scope: string?;
local Options: Parser.Options = {}

local Channels: { [string]: { Count: number, Listening: boolean } } = {
	Reliable = { Count = 0, Listening = false },
	Unreliable = { Count = 0, Listening = false },
}

local Writers = {}

local TypePrefabs = Prefabs.Types
local AssertPrefabs = Prefabs.Asserts
local Primitives = Prefabs.Primitives

local function GenerateEnumLiterals(Enums: { string }): string
	local Literal = ""
	for Index, EnumItem in Enums do
		Literal ..= `"{EnumItem}"{Index < #Enums and " | " or ""}`
	end
	return Literal
end

local function GetTypesPath(Identifier: string, Scope: string?, Write: boolean): string
	return `Types.{Scope and `{Scope}.` or ""}{Write and "Write" or "Read"}{Identifier}`
end

function Writers.Type(Identifier: string, Type: string, Optional: boolean, Read: string, Write: string, Reference: string?, Simple: boolean?, Arguments: string?): string
	if Optional then
		Type = `{Type}?`
	end

	local Result = Builder.new("\n")
	
	local Path = Scope and `.{Scope}` or ""
	local Prefix = (not Reference and Scope) and `{Scope}_` or ""
	local LuauType = `{Prefix}{Reference or Identifier}`

	if not Reference then
        LuauTypes.Push(`export type {Prefix}{Identifier} = {Type}`, 1)
	end
	
	Result.Push(`function {GetTypesPath(Identifier, Scope, true)}(Value: {LuauType}{Arguments and ", " .. Arguments or ""})`)
	Result.PushMultiline(Write, 0, 0)
	Result.Push(`end`, 2)
	Result.Push(`function {GetTypesPath(Identifier, Scope, false)}(): {LuauType}`)
	if not Simple then
		Result.Push(`local Value: {LuauType};`, 1, 1)
	end
	Result.PushMultiline(Read, 0, 0)
	if not Simple then
		Result.Push("return Value", 1, 1)
	end
	Result.Push(`end`)

	return Result.Dump()
end

function Writers.Optional(ReadBody: string, WriteBody: string, Variable: string, Instance: boolean?): (string, string)
	local Read = Builder.new()
	local Write = Builder.new()

	if Instance then
		local ReadLines = string.split(ReadBody, "\n")
		table.remove(ReadLines, 1)

		Read.Push("RecieveInstanceCursor += 1", 1, 1)
		Read.Push(`if RecieveInstances[RecieveInstanceCursor] then`, 1, 1)
		Read.PushLines(ReadLines, 0, 1)
		Read.Push("else", 1, 1)
		Read.Push(`{Variable} = nil`, 1, 2)
		Read.Push("end", 1, 1)

		Write.Push(`table.insert(SendInstances, {Variable} or false :: any)`, 1, 1)
	else
		Read.Push(OPTIONAL, 1, 1)
		Read.PushMultiline(ReadBody, 0, 1)
		Read.Push("end", 1, 1)

		Write.Push(Prefabs.Types.u8.Write(`({Variable} ~= nil) and 1 or 0`), 1, 1)
		Write.Push(`if {Variable} ~= nil then`, 1, 1)
		Write.PushMultiline(WriteBody, 0, 1)
		Write.Push("end", 1, 1)
	end

	return Read.Dump(), Write.Dump()
end

function Writers.TypeDeclaration(
	TypeDeclaration: Parser.TypeDeclaration,
	Variable: string?
): (string, string, string)
	local Value = TypeDeclaration.Value
	local Primitive = Primitives[Value.Primitive]
	if not Primitive then
		error(`Missing primitive for {Value.Primitive}`)
	end

	local Type = Primitive.Type
	if type(Type) == "function" then
		Type = Type(TypeDeclaration)
	end

	if Value.Array then
		Type = `\{{Type}\}`
	end

	local Read, Write = Primitive.Generate(TypeDeclaration, Variable)
	if Value.Optional then
		Read, Write = Writers.Optional(Read, Write, Variable or "Value", Value.Primitive == "Instance")
	end

	return Type, Read, Write
end

function Writers.EnumDeclaration(
	EnumDeclaration: Parser.EnumDeclaration,
	Variable: string?
): (string, string, string)
	local Value = EnumDeclaration.Value
	local Enums = Value.Enums
	local Variable = Variable or "Value"

	--> Builders
	local Read = Builder.new()
	local Write = Builder.new()
	local Type = GenerateEnumLiterals(Enums)

	--> Write operation
	for Index, EnumItem in Enums do
		Write.Push(`{Index > 1 and "else" or ""}if {Variable} == "{EnumItem}" then`, 1, 1)
		Write.Push(TypePrefabs.u8.Write(Index - 1), 1, 2)
	end
	Write.Push("else", 1, 1)
	Write.Push(`error(\`Unexpected enum: \{{Variable}\}, expectd one of {Type}.\`)`, 1, 2)
	Write.Push("end", 1, 1)

	-- Read operation
	Read.Push(TypePrefabs.u8.Read("local Index"), 1, 1)
	for Index, EnumItem in Enums do
		Read.Push(`{Index > 1 and "else" or ""}if Index == {Index - 1} then`, 1, 1)
		Read.Push(`{Variable} = "{EnumItem}"`, 1, 2)
	end
	Read.Push("else", 1, 1)
	Read.Push(`error(\`Unexpected enum: \{{Variable}\}\`)`, 1, 2)
	Read.Push("end", 1, 1)

	Read = Read.Dump()
	Write = Write.Dump()

	if Value.Optional then
		Read, Write = Writers.Optional(Read, Write, Variable or "Value")
	end

	return Type, Read, Write
end

function Writers.TypeReference(TypeReference: Parser.TypeReference, Tabs: number, Variable: string, Read: Builder.Builder, Write: Builder.Builder): string
	local Value = TypeReference.Value

	local Array = Value.Array
	local Reference = Value.Reference
	local ReferenceScope = Value.Scope

	local Prefix = ReferenceScope and `{ReferenceScope}_` or ""
	local ReadReference = GetTypesPath(Reference, ReferenceScope, false)
	local WriteReference = GetTypesPath(Reference, ReferenceScope, true)

	if Array then
		Prefabs.Structures.Array(
			Variable, 
			{
				Type = "Reference", 
				Read = ReadReference, 
				Write = WriteReference
			},
			Array, Read, Write, 1
		)
	else
		Read.Push(`{Variable} = {ReadReference}()`, 1, Tabs)
		Write.Push(`{WriteReference}({Variable})`, 1, Tabs)
	end

	return `{Prefix}{Reference}`
end

function Writers.StructDeclaration(StructDeclaration: Parser.StructDeclaration): string
	local Type = Builder.new()
	local Read = Builder.new()
	local Write = Builder.new()

	local function BuildStructType(
		StructDeclaration: Parser.StructDeclaration,
		Tabs: number,
		Indent: number,
		Path: string
	)
		local Value = StructDeclaration.Value
		local Optional = Value.Optional
		local StructTabs = Tabs

		if Optional then
			Read.Push(OPTIONAL, 1, StructTabs)
			Write.Push(Prefabs.Types.u8.Write(`({Path} ~= nil) and 1 or 0`), 1, StructTabs)
			Write.Push(`if {Path} ~= nil then`, 1, StructTabs)
			Tabs += 1
		end

		Type.Push(`{Indent > 0 and `{Value.Identifier}: ` or ""}\{`, 1, Indent)
		Read.Push(`{Path} = \{\} :: any`, 1, Tabs)

		for Index, Field in Value.Fields do
			local FieldType: string
			local FieldValue = Field.Value
			local FieldIdentifier = FieldValue.Identifier
			local Variable = `{Path}.{FieldIdentifier}`

			if Field.Type == "TypeDeclaration" or Field.Type == "EnumDeclaration" then
				local Writer = Writers[Field.Type]
				local DeclarationType, DeclarationRead, DeclarationWrite = Writer(Field, Variable)

				if Field.Type == "EnumDeclaration" then
					DeclarationRead = string.gsub(DeclarationRead, `{Variable} ==`, `{FieldIdentifier} ==`)
				end

				FieldType = DeclarationType
				Read.PushLines(string.split(DeclarationRead, "\n"), 0, Tabs - 1)
				Write.PushLines(string.split(DeclarationWrite, "\n"), 0, Tabs - 1)
			elseif Field.Type == "StructDeclaration" then
				BuildStructType(Field :: Parser.StructDeclaration, Tabs, Indent + 1, Variable)
				continue
			elseif Field.Type == "TypeReference" then
				local TypeReference: Parser.TypeReference = Field :: Parser.TypeReference
				FieldType = Writers.TypeReference(TypeReference, Tabs, Variable, Read, Write)

				if FieldValue.Array then
					FieldType = `\{{FieldType}\}`
				end
			end

			if FieldValue.Optional then
				FieldType = `({FieldType})?`
			end

			Type.Push(`{FieldIdentifier}: {FieldType}{Index < #Value.Fields and "," or ""}`, 1, Indent + 1)
		end

		if Optional then
			Read.Push("end", 1, StructTabs)
			Write.Push("end", 1, StructTabs)
		end

		Type.Push(`}{StructDeclaration.Value.Optional and "?" or ""}{Indent > 0 and "," or ""}`, Indent > 0 and 1 or 0, Indent)
	end

	BuildStructType(StructDeclaration, 1, 0, "Value")

	return Type.Dump(), Read.Dump(), Write.Dump()
end

local function WriteBody(Identifier: string, Data: Parser.Declaration, Index: number, Invoking: boolean?): string
	local Read = Builder.new()
	local Write = Builder.new()

	local Type, Reference
	local DataValue = Data.Value
	Write.Push(TypePrefabs.u8.Write(Index), 1, 1)
	
	if Invoking ~= nil then
		Write.Push(TypePrefabs.u8.Write("InvocationIdentifier"), 1, 1)
		
		if not Invoking then
			Write.Push(TypePrefabs.u8.Write("1"), 1, 1)

			Read.Push(`local {TypePrefabs.u8.Read("Success")} == 1`, 1, 1)
			Read.Push(`if not Success then`, 1, 1)
			Read.Push(`error("Server encountered an error.")`, 1, 2)
			Read.Push(`end`, 1, 1)
		end
	end

	if Data.Type == "TypeReference" then
		local TypeReference: Parser.TypeReference = Data :: Parser.TypeReference
		Type = Writers.TypeReference(TypeReference, 1, "Value", Read, Write)
		Reference = Type

		if DataValue.Array then
			Type = `\{{Type}\}`
		end
	else
		local Writer = Writers[Data.Type]
		local DeclarationType, DeclarationRead, DeclarationWrite = Writer(Data)
		DeclarationType = string.gsub(DeclarationType, "\n", " ")
		DeclarationType = string.gsub(DeclarationType, "\t", "")

		Type = DeclarationType
		Read.Push(DeclarationRead, 0)
		Write.Push(DeclarationWrite, 0)
	end

	if DataValue.Optional then
		Type = `({Type})?`
	end

	if Reference then
		Read.PushFront(`local Value: {Type};`, 1, 1)
		Read.Push(`return Value`, 1, 1)
	end

	--Read.PushFront(`local Value: {Type};`, 1, 1)
	--LuauTypes.Push(`export type {Identifier} = {Type}`)
	Types.Push(Writers.Type(Identifier, Type, Data.Value.Optional, Read.Dump(), Write.Dump(), Type, Reference ~= nil, (Invoking ~= nil) and "InvocationIdentifier: number" or nil), 0)
	
	return Type
end

function Writers.EventDeclaration(
	EventDeclaration: Parser.EventDeclaration,
	Context: "Client" | "Server"
): string
	local Value = EventDeclaration.Value
	local IsServer = (Context == "Server")
	local IsReliable = (Value.Type == "Reliable")

	local Arguments = (IsServer and "Player, " or "")
	local CallbackArguments = (IsServer and "Player :: any, " or "")

    local Channel = Channels[Value.Type]
	local EventIndex = Channel.Count
	local Identifier = `EVENT_{Value.Identifier}`

	--> Type generation
	local Type = WriteBody(Identifier, Value.Data, EventIndex)

	--> Body generation
	local Event = Builder.new(nil, Scope and 1 or 0)
	local WritePath = `{GetTypesPath(Identifier, Scope, true)}(Value)`

	Event.Push(`{Value.Identifier} = \{`, 1, 1)
	
	if Value.From ~= Context then
		local Index = `{Value.Type}[{EventIndex}]`
		local Queue = `Queue.{Index}`
        local Events = `Events.{Index}`

		--> Allocate queue table at require time instead of creating one at runtime
		Types.PushFront(`{Queue} = table.create(256)`)

		Event.Push(`On = function(Listener: ({Arguments}{Type}) -> ())`, 1, 2)
		Event.Push(`{Events} = Listener`, 1, 3)
		Event.Push(`task.spawn(function()`, 1, 3)
		Event.Push(`local EventQueue = {Queue} or \{\}`, 1, 4)
		--Event.Push(`if not Queue then return end`, 1, 4)
		Event.Push(`{Queue} = nil`, 1, 4)
		Event.Push(`for Index, Arguments in EventQueue do`, 1, 4)
		Event.Push(`Listener(table.unpack(Arguments))`, 1, 5)
		Event.Push(`end`, 1, 4)
		Event.Push(`end)`, 1, 3)
		Event.Push(`end`, 1, 2)

		local EventBuilder = (IsReliable and ReliableEvents or UnreliableEvents)
		EventBuilder.Push(`{Channel.Listening and "elseif" or "if"} Index == {EventIndex} then`, 1, 2)
		EventBuilder.Push(`local Value = {GetTypesPath(Identifier, Scope, false)}()`, 1, 3)
		EventBuilder.Push(`if {Events} then`, 1, 3)
		EventBuilder.Push(`{Events}({CallbackArguments}Value)`, 1, 4)
		EventBuilder.Push("else", 1, 3)
		EventBuilder.Push(`if #{Queue} > 256 then warn("[Blink]: Event queue of \\"{Value.Identifier}\\" exceeded 256, did you forget to implement a listener?") end`, 1, 4)
		EventBuilder.Push(`table.insert({Queue}, \{{CallbackArguments}Value\})`, 1, 4)
		EventBuilder.Push("end", 1, 3)

		Channel.Listening = true
	elseif IsServer then
        --> Single fire
        Event.Push(`Fire = function(Player: Player, Value: {Type})`, 1, 2)
        if IsReliable then
            Event.Push(`Load(PlayersMap[Player])`, 1, 3)
            Event.Push(WritePath, 1, 3)
            Event.Push(`PlayersMap[Player] = Save()`, 1, 3)
        else
            Event.Push(`Load()`, 1, 3)
            Event.Push(WritePath, 1, 3)
            Event.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Event.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Event.Push(`Unreliable:FireClient(Player, Buffer, SendInstances)`, 1, 3)
        end
        Event.Push(`end,`, 1, 2)

        --> Fire all
        Event.Push(`FireAll = function(Value: {Type})`, 1, 2)
		Event.Push(`Load()`, 1, 3)
		Event.Push(WritePath, 1, 3)
        if IsReliable then
			Event.Push(SAVE_BODY.Header, 1, 3)
            Event.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
			Event.PushLines(SAVE_BODY.Body, 0, 4)
			Event.Push(`end`, 1, 3)
        else
            Event.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Event.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Event.Push(`Unreliable:FireAllClients(Buffer, SendInstances)`, 1, 3)
        end
        Event.Push(`end,`, 1, 2)

        --> Fire list
        Event.Push(`FireList = function(List: \{Player\}, Value: {Type})`, 1, 2)
		Event.Push(`Load()`, 1, 3)
		Event.Push(WritePath, 1, 3)
        if IsReliable then
			Event.Push(SAVE_BODY.Header, 1, 3)
            Event.Push(`for _, Player in List do`, 1, 3)
			Event.PushLines(SAVE_BODY.Body, 0, 4)
			Event.Push(`end`, 1, 3)
        else
            Event.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Event.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Event.Push(`for _, Player in List do`, 1, 3)
			Event.Push(`Unreliable:FireClient(Player, Buffer, SendInstances)`, 1, 4)
			Event.Push(`end`, 1, 3)
        end
        Event.Push(`end,`, 1, 2)

        --> Fire except
        Event.Push(`FireExcept = function(Except: Player, Value: {Type})`, 1, 2)
		Event.Push(`Load()`, 1, 3)
		Event.Push(WritePath, 1, 3)
        if IsReliable then
			Event.Push(SAVE_BODY.Header, 1, 3)
            Event.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
			Event.Push(`if Player == Except then continue end`, 1, 4)
            Event.PushLines(SAVE_BODY.Body, 0, 4)
            Event.Push(`end`, 1, 3)
        else
            Event.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Event.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Event.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
			Event.Push(`if Player == Except then continue end`, 1, 4)
			Event.Push(`Unreliable:FireClient(Player, Buffer, SendInstances)`, 1, 4)
			Event.Push(`end`, 1, 3)
        end
        Event.Push(`end`, 1, 2)
    else
        Event.Push(`Fire = function(Value: {Type})`, 1, 2)
        if IsReliable then
            Event.Push(WritePath, 1, 3)
        else
            Event.Push(`local Previous = Save()`, 1, 3)
            Event.Push(`Load()`, 1, 3)
            Event.Push(WritePath, 1, 3)
            Event.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Event.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Event.Push(`Unreliable:FireServer(Buffer, SendInstances)`, 1, 3)
            Event.Push(`Load(Previous)`, 1, 3)
        end
        Event.Push(`end`, 1, 2)
    end

	Event.Push(`},`, 1, 1)
	return Event.Dump()
end

function Writers.FunctionDeclaration(
	FunctionDeclaration: Parser.FunctionDeclaration,
	Context: "Client" | "Server"
): string
	local Value = FunctionDeclaration.Value
	local Yield = Value.Yield

	local IsFuture = (Yield == "Future")
	local IsPromise = (Yield == "Promise")
	local IsCoroutine = (Yield == "Coroutine")

	if IsFuture and not Options.FutureLibrary then
		error(`Cannot use yield type: "Future", without providing a path to the future library.`)
	end

	if IsPromise and not Options.PromiseLibrary then
		error(`Cannot use yield type: "Promise", without providing a path to the promise library.`)
	end

	local Channel = Channels.Reliable
	local FunctionIndex = Channel.Count

	local Index = `Reliable[{FunctionIndex}]`
	local Queue = `Queue.{Index}`
    local Events = `Events.{Index}`

	local DataIdentifier = `FUNCTION_DATA_{Value.Identifier}`
	local ReturnIdentifier = `FUNCTION_RETURN_{Value.Identifier}` 

	--> Type generation
	local DataType = WriteBody(DataIdentifier, Value.Data, FunctionIndex, true)
	local ReturnType = WriteBody(ReturnIdentifier, Value.Return, FunctionIndex, false)

	--> Allocate queue table at require time instead of creating one at runtime
	Types.PushFront(`{Queue} = table.create(256)`)

	--> Body generation
	local Function = Builder.new(nil, Scope and 1 or 0)
	Function.Push(`{Value.Identifier} = \{`, 1, 1)

	if Context == "Server" then
		Function.Push(`On = function(Callback: (Player, {DataType}) -> ({ReturnType}))`, 1, 2)
		--Function.Push(`assert({Events} == nil, "A function callback can only bet set once")`, 1, 3)
		Function.Push(`{Events} = function(Player: Player, Value: {DataType}, InvocationIdentifier: number)`, 1, 3)

		Function.Push(`local Success, Return = pcall(function() return Callback(Player, Value) end)`, 1, 4)

		Function.Push(`Load(PlayersMap[Player])`, 1, 4)
		Function.Push(`if not Success then`, 1, 4)
		Function.Push(`buffer.writeu8(SendBuffer, Allocate(1), {FunctionIndex})`, 1, 5)
		Function.Push(`buffer.writeu8(SendBuffer, Allocate(1), InvocationIdentifier)`, 1, 5)
		Function.Push(`buffer.writeu8(SendBuffer, Allocate(1), 0)`, 1, 5)
		Function.Push(`else`, 1, 4)
		Function.Push(`{GetTypesPath(ReturnIdentifier, Scope, true)}(Return, InvocationIdentifier)`, 1, 5)
		Function.Push(`end`, 1, 4)
        Function.Push(`PlayersMap[Player] = Save()`, 1, 4)
		Function.Push(`end`, 1, 3)

		Function.Push(`task.defer(function()`, 1, 3)
		Function.Push(`local FunctionQueue = {Queue} or \{\}`, 1, 4)
		Function.Push(`{Queue} = nil`, 1, 4)
		Function.Push(`for Index, Arguments in FunctionQueue do`, 1, 4)
		Function.Push(`{Events}(table.unpack(Arguments))`, 1, 5)
		Function.Push(`end`, 1, 4)
		Function.Push(`end)`, 1, 3)

		Function.Push(`end`, 1, 2)

		ReliableEvents.Push(`{Channel.Listening and "elseif" or "if"} Index == {FunctionIndex} then`, 1, 2)
		ReliableEvents.Push(`local {TypePrefabs.u8.Read("InvocationIdentifier")}`, 1, 3)
		ReliableEvents.Push(`local Value = {GetTypesPath(DataIdentifier, Scope, false)}()`, 1, 3)
		ReliableEvents.Push(`if {Events} then`, 1, 3)
		ReliableEvents.Push(`{Events}(Player, Value, InvocationIdentifier)`, 1, 4)
		ReliableEvents.Push(`else`, 1, 3)
		ReliableEvents.Push(`if #{Queue} > 256 then warn("[Blink]: Function queue of \\"{Value.Identifier}\\" exceeded 256, did you forget to implement a callback?") end`, 1, 4)
		ReliableEvents.Push(`table.insert({Queue}, \{Player :: any, Value, InvocationIdentifier\})`, 1, 4)
		ReliableEvents.Push(`end`, 1, 3)
	else
		Function.Push(`Invoke = function(Value: {DataType})`, 1, 2)
		Function.Push(`local InvocationIdentifier = Invoke()`, 1, 3)
		Function.Push(`{GetTypesPath(DataIdentifier, Scope, true)}(Value, InvocationIdentifier)`, 1, 3)
		
		if IsCoroutine then
			Function.PushLines(YIELD_BODY, 0, 3)
		elseif IsFuture then
			Function.Push(`return Future.Try(function()`, 1, 3)
			Function.PushLines(YIELD_BODY, 0, 4)
			Function.Push(`end)`, 1, 3)
		elseif IsPromise then
			Function.Push(`return Promise.new(function(Resolve, Reject, OnCancel)`, 1, 3)
			Function.Push("OnCancel(function()", 1, 4)
			Function.Push(`Calls[InvocationIdentifier] = nil`, 1, 5)
			Function.Push("end)", 1, 4)
			Function.Push(YIELD_BODY[1], 1, 4)
			Function.Push(YIELD_BODY[2], 1, 4)
			Function.Push("if not Success then Reject(Return) end", 1, 4)
			Function.Push("Resolve(Return)", 1, 4)
			Function.Push(`end)`, 1, 3)
		end

		Function.Push(`end`, 1, 2)

		ReliableEvents.Push(`{Channel.Listening and "elseif" or "if"} Index == {FunctionIndex} then`, 1, 2)
		ReliableEvents.Push(`local {TypePrefabs.u8.Read("InvocationIdentifier")}`, 1, 3)
		ReliableEvents.Push(`if Calls[InvocationIdentifier] then`, 1, 3)
		ReliableEvents.Push(`local Success, Value = pcall(function() return {GetTypesPath(ReturnIdentifier, Scope, false)}() end)`, 1, 4)
		ReliableEvents.Push(`task.spawn(Calls[InvocationIdentifier], Success, Value)`, 1, 4)
		ReliableEvents.Push(`end`, 1, 3)
	end

	Channel.Listening = true
	Function.Push(`},`, 1, 1)

	return Function.Dump()
end

function Writers.ScopeDeclaration(ScopeDeclaration: Parser.ScopeDeclaration, Context: "Client" | "Server")
	local Value = ScopeDeclaration.Value

	local Identifier = Value.Identifier
	local Declarations = Value.Declarations

	Scope = Identifier
	Types.Push(`Types.{Identifier} = \{\}`)
	Return.Push(`{Identifier} = \{`, 1, 1)
	Writers.Declarations(Declarations, Context)
	Return.Push(`\},`, 1, 1)
	Scope = nil
end

function Writers.Declarations(Declarations: {Parser.Declaration}, Context: "Client" | "Server")
	for Index, Declaration in Declarations do
		local Writer = Writers[Declaration.Type]
		if not Writer then
			warn(`{Declaration.Type} has no writer.`)
			continue
		end

		if Declaration.Type == "EventDeclaration" or Declaration.Type == "FunctionDeclaration" then
			Return.Push(Writer(Declaration, Context), 0)
			;(Channels[Declaration.Value.Type] or Channels.Reliable).Count += 1
			continue
		elseif Declaration.Type == "ScopeDeclaration" then
			Writer(Declaration, Context)
			continue
		end

		local Type, Read, Write = Writer(Declaration)
		Types.Push(Writers.Type(Declaration.Value.Identifier, Type, Declaration.Value.Optional, Read, Write), 0)
	end
end

return function(Context: "Client" | "Server", AbstractSyntaxTree: Parser.Body, UserOptions: Parser.Options): string
	--> Reset previous generation
	Types.Dump()
	LuauTypes.Dump()
	Imports.Dump()
	Return.Dump()
	ReliableEvents.Dump()
	UnreliableEvents.Dump()

	Options = UserOptions
	Channels.Reliable.Count = 0
	Channels.Unreliable.Count = 0
	Channels.Reliable.Listening = false
	Channels.Unreliable.Listening = false

	--> Import async libraries
	if UserOptions.FutureLibrary then
		Imports.Push(`local Future = require({UserOptions.FutureLibrary})`)
	end

	if UserOptions.PromiseLibrary then
		Imports.Push(`local Promise = require({UserOptions.PromiseLibrary})`)
	end

	--> Generate remote connections
	local Signal = (Context == "Client" and "OnClientEvent" or "OnServerEvent")
	local Arguments = (Context == "Server" and "Player: Player, " or "") .. "Buffer: buffer, Instances: {Instance}"

	ReliableEvents.Push(`Reliable.{Signal}:Connect(function({Arguments})`)
	UnreliableEvents.Push(`Unreliable.{Signal}:Connect(function({Arguments})`)

	ReliableEvents.Push(EVENT_BODY)
	UnreliableEvents.Push(EVENT_BODY)

	--> Generate replication loop
	local Replication: string;
	if Options.ManualReplication then
		Replication = ""
		Return.Push("StepReplication = StepReplication,", 1, 1)
	else
		local ReplicationBuilder = Builder.new()
		ReplicationBuilder.PushLines(AUTOMATIC_REPLICATION[Context], 0, 0)
		Replication = ReplicationBuilder.Dump()
	end

	--> Generate types & events/functions
	Writers.Declarations(AbstractSyntaxTree.Value, Context)

	--> Close remote connection functions
	if Channels.Reliable.Listening then
		ReliableEvents.Push("end", 1, 2)
	end

	if Channels.Unreliable.Listening then
		UnreliableEvents.Push("end", 1, 2)
	end

	ReliableEvents.Push("end", 1, 1)
	UnreliableEvents.Push("end", 1, 1)

	ReliableEvents.Push("end)", 2)
	UnreliableEvents.Push("end)")

	--> Generate context source
	local Source = Sources[Context]
	return DIRECTIVES
		.. (if not _G.BUNDLED then string.format(DEBUUG_GLOBALS, string.lower(Context), string.lower(Context)) else "")
        .. Source[1]
		.. Imports.Dump()
		.. Sources.Base
		.. LuauTypes.Dump()
		.. Types.Dump()
		.. Source[2]
		.. Replication
		.. ReliableEvents.Dump()
		.. UnreliableEvents.Dump()
		.. `\nreturn \{\n{Return.Dump()}\}`
end
