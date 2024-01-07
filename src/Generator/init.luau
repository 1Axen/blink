--!native
--!optimize 2

local fs = require("@lune/fs")

local Parser = require("../Parser")
local Builder = require("../Modules/Builder")
local Prefabs = require("./Prefabs")

local Sources = {
	Base = if _G.BUNDLED then (require("Base") :: any) else fs.readFile("./Templates/Base.txt"),
	Client = string.split(if _G.BUNDLED then (require("Client") :: any) else fs.readFile("./Templates/Client.txt"), "-- SPLIT --"),
	Server = string.split(if _G.BUNDLED then (require("Server") :: any) else fs.readFile("./Templates/Server.txt"), "-- SPLIT --"),
}

local OPTIONAL = `if buffer.readu8(RecieveBuffer, Read(1)) == 1 then`
local EVENT_BODY =
	"\tRecieveCursor = 0\n\tRecieveBuffer = Buffer\n\tlocal Size = buffer.len(RecieveBuffer)\n\twhile RecieveCursor < Size do\n\t\tlocal Index = buffer.readu8(RecieveBuffer, Read(1))"

local Types = Builder.new()
local Packets = Builder.new()
local ReliableEvents = Builder.new()
local UnreliableEvents = Builder.new()

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

function Writers.Type(Identifier: string, Type: string, Optional: boolean, Read: string, Write: string, Reference: string?, Simple: boolean?): string
	if Optional then
		Type = `{Type}?`
	end

	local Result = Builder.new("\n")
	if not Reference then
        Result.Push(`export type {Identifier} = {Type}`, 2)
	end
	
	Result.Push(`function Types.Write{Identifier}(Value: {Reference or Identifier})`)
	Result.Push(Write, 0)
	Result.Push(`end`, 2)
	Result.Push(`function Types.Read{Identifier}(): {Reference or Identifier}`)
	if not Simple then
		Result.Push(`local Value: {Reference or Identifier};`, 1, 1)
	end
	Result.Push(Read, 0)
	if not Simple then
		Result.Push("return Value", 1, 1)
	end
	Result.Push(`end`)

	return Result.Dump()
end

function Writers.Optional(ReadBody: string, WriteBody: string, Variable: string): (string, string)
	local Read = Builder.new()
	local Write = Builder.new()

	local ReadLines = string.split(ReadBody, "\n")
	local WriteLines = string.split(WriteBody, "\n")

	Read.Push(OPTIONAL, 1, 1)
	Read.PushLines(ReadLines, 0, 1)
	Read.Push("end", 1, 1)

	Write.Push(Prefabs.Types.u8.Write(`({Variable} ~= nil) and 1 or 0`), 1, 1)
	Write.Push(`if {Variable} ~= nil then`, 1, 1)
	Write.PushLines(WriteLines, 0, 1)
	Write.Push("end", 1, 1)

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
	if Value.Array then
		Type = `\{{Type}\}`
	end

	local Read, Write = Primitive.Generate(Value.Array, Value.Range, Variable)
	if Value.Optional then
		Read, Write = Writers.Optional(Read, Write, Variable or "Value")
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

function Writers.StructDeclaration(StructDeclaration: Parser.StructDeclaration): string
	local Type = Builder.new()
	local Read = Builder.new()
	local Write = Builder.new()

	local function BuildStructType(StructDeclaration: Parser.StructDeclaration, Tabs: number, Indent: number, Path: string)
		local Value = StructDeclaration.Value
		local Optional = Value.Optional
		local StructTabs = Tabs

		if Optional then
			Read.Push(OPTIONAL, 1, StructTabs)
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
				BuildStructType(Field, Tabs, Indent + 1, Variable)
				continue
			elseif Field.Type == "TypeReference" then
				local TypeReference: Parser.TypeReference = Field
				FieldType = TypeReference.Value.Reference
				Read.Push(`{Variable} = Types.Read{FieldType}()`, 1, Tabs)
				Write.Push(`Types.Write{FieldType}({Variable})`, 1, Tabs)
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

		Type.Push("}", Indent > 0 and 1 or 0, Indent)
	end

	BuildStructType(StructDeclaration, 1, 0, "Value")

	return Type.Dump(), Read.Dump(), Write.Dump()
end

function Writers.PacketDeclaration(
	PacketDeclaration: Parser.PacketDeclaration,
	Context: "Client" | "Server",
	ReliableEvents: Builder.Builder,
	UnreliableEvents: Builder.Builder
): string
	local Value = PacketDeclaration.Value
	local IsServer = (Context == "Server")
	local IsReliable = (Value.Type == "Reliable")
	local Arguments = (IsServer and "Player, " or "")

	local Data = Value.Data
	local DataValue = Data.Value

    local Channel = Channels[Value.Type]
	local PacketIndex = Channel.Count

	local Type: string
    local Reference: string?
	local Identifier = `PACKET_{Value.Identifier}`

	local Read = Builder.new()
	local Write = Builder.new()
	local Packet = Builder.new()

	--> Type generation
	Packet.Push(`{Value.Identifier} = \{`, 1, 1)
	Write.Push(TypePrefabs.u8.Write(PacketIndex), 1, 1)

	if Data.Type == "TypeReference" then
		local TypeReference: Parser.TypeReference = Value.Data

		Type = TypeReference.Value.Reference
		Reference = TypeReference.Value.Reference

		Read.Push(`return Types.Read{Reference}()`, 1, 1)
		Write.Push(`Types.Write{Reference}(Value)`, 1, 1)
	else
		local Writer = Writers[Data.Type]
		local DeclarationType, DeclarationRead, DeclarationWrite = Writer(Data)
		DeclarationType = string.gsub(DeclarationType, "\n", " ")
		DeclarationType = string.gsub(DeclarationType, "\t", "")

		Type = DeclarationType
		Read.Push(DeclarationRead, 0)
		Write.Push(DeclarationWrite, 0)
	end

	Types.Push(Writers.Type(Identifier, Type, DataValue.Optional, Read.Dump(), Write.Dump(), Type, Reference ~= nil), 0)

	--> Body generation
	if Value.From ~= Context then
		local Index = `{Value.Type}[{PacketIndex}]`
		local Queue = `Queue.{Index}`
        local Events = `Events.{Index}`

		--> Allocate queue table at require time instead of creating one at runtime
		Types.PushFront(`{Queue} = table.create(256)`)

		Packet.Push(`Listen = function(Listener: ({Arguments}{Type}) -> ())`, 1, 2)
		Packet.Push(`{Events} = Listener`, 1, 3)
		Packet.Push(`task.spawn(function()`, 1, 3)
		Packet.Push(`local Queue = {Queue} or \{\}`, 1, 4)
		--Packet.Push(`if not Queue then return end`, 1, 4)
		Packet.Push(`{Queue} = nil`, 1, 4)
		Packet.Push(`for Index, Arguments in Queue do`, 1, 4)
		Packet.Push(`Listener(table.unpack(Arguments))`, 1, 5)
		Packet.Push(`end`, 1, 4)
		Packet.Push(`end)`, 1, 3)
		Packet.Push(`end`, 1, 2)

		local EventBuilder = (IsReliable and ReliableEvents or UnreliableEvents)
		EventBuilder.Push(`{Channel.Listening and "elseif" or "if"} Index == {PacketIndex} then`, 1, 2)
		EventBuilder.Push(`local Value = Types.Read{Identifier}()`, 1, 3)
		EventBuilder.Push(`if {Events} then`, 1, 3)
		EventBuilder.Push(`{Events}({Arguments}Value)`, 1, 4)
		EventBuilder.Push("else", 1, 3)
		EventBuilder.Push(`if #{Queue} > 256 then warn("[DeclareNet]: Packet queue of \\"{Value.Identifier}\\" exceeded 256, did you forget to implement Listen?") end`, 1, 4)
		EventBuilder.Push(`table.insert({Queue}, \{{Arguments}Value\})`, 1, 4)
		EventBuilder.Push("end", 1, 3)

		Channel.Listening = true
	elseif IsServer then
        --> Single fire
        Packet.Push(`Fire = function(Player: Player, Value: {Type})`, 1, 2)
        if IsReliable then
            Packet.Push(`Load(PlayersMap[Player])`, 1, 3)
            Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
            Packet.Push(`PlayersMap[Player] = Save()`, 1, 3)
        else
            Packet.Push(`Load()`, 1, 3)
            Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
            Packet.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Packet.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Packet.Push(`Unreliable:FireClient(Player, Buffer)`, 1, 3)
        end
        Packet.Push(`end,`, 1, 2)

        --> Fire all
        Packet.Push(`FireAll = function(Value: {Type})`, 1, 2)
        Packet.Push(`Load()`, 1, 3)
        Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
        if IsReliable then
            Packet.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
            Packet.Push(`PlayersMap[Player] = Save()`, 1, 4)
            Packet.Push(`end`, 1, 3)
        else
            Packet.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Packet.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Packet.Push(`Unreliable:FireAllClients(Buffer)`, 1, 3)
        end
        Packet.Push(`end,`, 1, 2)

        --> Fire list
        Packet.Push(`FireList = function(List: \{Player\}, Value: {Type})`, 1, 2)
        Packet.Push(`Load()`, 1, 3)
        Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
        if IsReliable then
            Packet.Push(`for _, Player in List do`, 1, 3)
            Packet.Push(`PlayersMap[Player] = Save()`, 1, 4)
            Packet.Push(`end`, 1, 3)
        else
            Packet.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Packet.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Packet.Push(`for _, Player in List do`, 1, 3)
            Packet.Push(`Unreliable:FireClient(Player, Buffer)`, 1, 4)
            Packet.Push(`end`, 1, 3)
        end
        Packet.Push(`end,`, 1, 2)

        --> Fire except
        Packet.Push(`FireExcept = function(Except: Player, Value: {Type})`, 1, 2)
        Packet.Push(`Load()`, 1, 3)
        Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
        if IsReliable then
            Packet.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
            Packet.Push(`if Player == Except then continue end`, 1, 4)
            Packet.Push(`PlayersMap[Player] = Save()`, 1, 4)
            Packet.Push(`end`, 1, 3)
        else
            Packet.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Packet.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Packet.Push(`for _, Player in Players:GetPlayers() do`, 1, 3)
            Packet.Push(`if Player == Except then continue end`, 1, 4)
            Packet.Push(`Unreliable:FireClient(Player, Buffer)`, 1, 4)
            Packet.Push(`end`, 1, 3)
        end
        Packet.Push(`end`, 1, 2)
    else
        Packet.Push(`Fire = function(Value: {Type})`, 1, 2)
        if IsReliable then
            Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
        else
            Packet.Push(`local Previous = Save()`, 1, 3)
            Packet.Push(`Load()`, 1, 3)
            Packet.Push(`Types.Write{Identifier}(Value)`, 1, 3)
            Packet.Push(`local Buffer = buffer.create(SendCursor)`, 1, 3)
            Packet.Push(`buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)`, 1, 3)
            Packet.Push(`Unreliable:FireServer(Buffer)`, 1, 3)
            Packet.Push(`Load(Previous)`, 1, 3)
        end
        Packet.Push(`end`, 1, 2)
    end

	Packet.Push(`},`, 1, 1)
	return Packet.Dump()
end

return function(Context: "Client" | "Server", AbstractSyntaxTree: Parser.Body, UserOptions: Parser.Options): string
	--> Reset previous generation
	Types.Dump()
	Packets.Dump()
	ReliableEvents.Dump()
	UnreliableEvents.Dump()

	Options = UserOptions
	Channels.Reliable.Count = 0
	Channels.Unreliable.Count = 0
	Channels.Reliable.Listening = false
	Channels.Unreliable.Listening = false

	--> Generate remote connections
	local Signal = (Context == "Client" and "OnClientEvent" or "OnServerEvent")
	local Arguments = (Context == "Server" and "Player: Player, " or "") .. "Buffer: buffer"

	ReliableEvents.Push(`Reliable.{Signal}:Connect(function({Arguments})`)
	UnreliableEvents.Push(`Unreliable.{Signal}:Connect(function({Arguments})`)

	ReliableEvents.Push(EVENT_BODY)
	UnreliableEvents.Push(EVENT_BODY)

	--> Generate replication loop
	local Replication = "\nRunService.Heartbeat:Connect(StepReplication)\n"
	if Options.ManualReplication then
		Replication = ""
		Packets.Push("StepReplication = StepReplication,", 1, 1)
	end

	--> Generate types & packets
	for Index, Declaration in AbstractSyntaxTree.Value do
		local Writer = Writers[Declaration.Type]
		if not Writer then
			warn(`{Declaration.Type} has no writer.`)
			continue
		end

		if Declaration.Type == "PacketDeclaration" then
			Packets.Push(Writer(Declaration, Context, ReliableEvents, UnreliableEvents), 0)
			Channels[Declaration.Value.Type].Count += 1

			continue
		end

		local Type, Read, Write = Writer(Declaration)
		Types.Push(Writers.Type(Declaration.Value.Identifier, Type, Declaration.Value.Optional, Read, Write), 0)
	end

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
	return "--!strict\n\n"
        .. Source[1]
		.. Sources.Base
		.. Types.Dump()
		.. Source[2]
		.. Replication
		.. ReliableEvents.Dump()
		.. UnreliableEvents.Dump()
		.. `\nreturn \{\n{Packets.Dump()}\}`
end
