--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reliable = Instance.new("RemoteEvent")
Reliable.Name = "DECLARE_NET_RELIABLE_REMOTE"
Reliable.Parent = ReplicatedStorage

local Unreliable = Instance.new("UnreliableRemoteEvent")
Unreliable.Name = "DECLARE_NET_UNRELIABLE_REMOTE"
Unreliable.Parent = ReplicatedStorage

local SendCursor = 0
local SendBuffer = buffer.create(64)

local RecieveCursor = 0
local RecieveBuffer = buffer.create(64)

type BufferSave = {Cursor: number, Buffer: buffer}

local function Read(Bytes: number)
    local Offset = RecieveCursor
    RecieveCursor += Bytes
    return Offset
end

local function Save(): BufferSave
    return {
        Cursor = SendCursor,
        Buffer = SendBuffer,
    }
end

local function Load(Save: BufferSave?)
    if Save then
        SendCursor = Save.Cursor
        SendBuffer = Save.Buffer
        return
    end

    SendCursor = 0
    SendBuffer = buffer.create(64)
end

local function Allocate(Bytes: number)
    local Len = buffer.len(SendBuffer)

    local Size = Len
    local InUse = (SendCursor + Bytes)
    
    if InUse > Size then
        --> Avoid resizing the buffer for every write
        while InUse > Size do
            Size *= 2
        end

        local Buffer = buffer.create(Size)
        buffer.copy(Buffer, 0, SendBuffer, 0, Len)
    end

    local Offset = SendCursor
    SendCursor += Bytes
    
    return Offset
end

local Types = {}
local Events: any = {
    Reliable = {},
    Unreliable = {}
}
local Queue: any = {
    Reliable = {},
    Unreliable = {}
}
export type Health = number

function Types.WriteHealth(Value: Health)
	buffer.writeu8(SendBuffer, Allocate(1), Value)
end

function Types.ReadHealth(): Health
	local Value: Health;
	Value = buffer.readu8(RecieveBuffer, Read(1))
	assert(Value >= 0)
	assert(Value <= 100)
	return Value
end

export type Array = {number}

function Types.WriteArray(Value: Array)
	for _, Item in Value do
		buffer.writeu8(SendBuffer, Allocate(1), Item)
	end
end

function Types.ReadArray(): Array
	local Value: Array;
	Value = table.create(8)
	for Index = 1, 8 do
		local Item = buffer.readu8(RecieveBuffer, Read(1))
		table.insert(Value, Item)
	end
	return Value
end

export type ArrayVariant = {number}

function Types.WriteArrayVariant(Value: ArrayVariant)
	buffer.writeu8(SendBuffer, Allocate(1), #Value)
	for _, Item in Value do
		buffer.writeu8(SendBuffer, Allocate(1), Item)
	end
end

function Types.ReadArrayVariant(): ArrayVariant
	local Value: ArrayVariant;
	local Length = buffer.readu8(RecieveBuffer, Read(1))
	assert(Length >= 1)
	assert(Length <= 200)
	Value = table.create(Length)
	for Index = 1, Length do
		local Item = buffer.readu8(RecieveBuffer, Read(1))
		table.insert(Value, Item)
	end
	return Value
end

export type Booleans = {boolean}?

function Types.WriteBooleans(Value: Booleans)
	buffer.writeu8(SendBuffer, Allocate(1), (Value ~= nil) and 1 or 0)
	if Value ~= nil then
		for _, Item in Value do
			buffer.writeu8(RecieveBuffer, Allocate(1), Item and 1 or 0)
		end
	end
end

function Types.ReadBooleans(): Booleans
	local Value: Booleans;
	if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
		Value = table.create(8)
		for Index = 1, 8 do
			local Item = (buffer.readu8(RecieveBuffer, Read(1)) == 1)
			table.insert(Value, Item)
		end
	end
	return Value
end

export type Username = string?

function Types.WriteUsername(Value: Username)
	buffer.writeu8(SendBuffer, Allocate(1), (Value ~= nil) and 1 or 0)
	if Value ~= nil then
		buffer.writeu8(RecieveBuffer, Allocate(1), Value and 1 or 0)
	end
end

function Types.ReadUsername(): Username
	local Value: Username;
	if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
		local Length = buffer.readu16(RecieveBuffer, Read(1))
		Value = buffer.readstring(RecieveBuffer, Read(Length), Length)
		assert(#Value >= 3)
		assert(#Value <= 20)
	end
	return Value
end

export type UnitVector = Vector3

function Types.WriteUnitVector(Value: UnitVector)
	local Vector = Value
	buffer.writef32(RecieveBuffer, Allocate(4), Vector.X)
	buffer.writef32(RecieveBuffer, Allocate(4), Vector.Y)
	buffer.writef32(RecieveBuffer, Allocate(4), Vector.Z)
end

function Types.ReadUnitVector(): UnitVector
	local Value: UnitVector;
	Value = Vector3.new(buffer.readf32(RecieveBuffer, Read(4)), buffer.readf32(RecieveBuffer, Read(4)), buffer.readf32(RecieveBuffer, Read(4)))
	assert(Value.Magnitude >= 0)
	assert(Value.Magnitude <= 1)
	return Value
end

export type State = "None" | "Dead" | "Down" | "Alive"?

function Types.WriteState(Value: State)
	buffer.writeu8(SendBuffer, Allocate(1), (Value ~= nil) and 1 or 0)
	if Value ~= nil then
		if Value == "None" then
			buffer.writeu8(SendBuffer, Allocate(1), 0)
		elseif Value == "Dead" then
			buffer.writeu8(SendBuffer, Allocate(1), 1)
		elseif Value == "Down" then
			buffer.writeu8(SendBuffer, Allocate(1), 2)
		elseif Value == "Alive" then
			buffer.writeu8(SendBuffer, Allocate(1), 3)
		else
			error(`Unexpected enum: {Value}, expectd one of "None" | "Dead" | "Down" | "Alive".`)
		end
	end
end

function Types.ReadState(): State
	local Value: State;
	if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
		local Index = buffer.readu8(RecieveBuffer, Read(1))
		if Index == 0 then
			Value = "None"
		elseif Index == 1 then
			Value = "Dead"
		elseif Index == 2 then
			Value = "Down"
		elseif Index == 3 then
			Value = "Alive"
		else
			error(`Unexpected enum: {Value}`)
		end
	end
	return Value
end

export type Entity = {
	Identifier: (number)?,
	Health: Health,
	LocalState: ("Replicated" | "Unreplicated")?,
	Character: State,
	Direction: UnitVector,
	Deep: {
		Empty: {number},
		Complex: {number},
		Vector: UnitVector
	}
}?

function Types.WriteEntity(Value: Entity)
	if Value ~= nil then
		buffer.writeu8(SendBuffer, Allocate(1), (Value.Identifier ~= nil) and 1 or 0)
		if Value.Identifier ~= nil then
			buffer.writeu8(SendBuffer, Allocate(1), Value.Identifier)
		end
		Types.WriteHealth(Value.Health)
		buffer.writeu8(SendBuffer, Allocate(1), (Value.LocalState ~= nil) and 1 or 0)
		if Value.LocalState ~= nil then
			if Value.LocalState == "Replicated" then
				buffer.writeu8(SendBuffer, Allocate(1), 0)
			elseif Value.LocalState == "Unreplicated" then
				buffer.writeu8(SendBuffer, Allocate(1), 1)
			else
				error(`Unexpected enum: {Value.LocalState}, expectd one of "Replicated" | "Unreplicated".`)
			end
		end
		Types.WriteState(Value.Character)
		Types.WriteUnitVector(Value.Direction)
		if Value.Deep ~= nil then
			for _, Item in Value.Deep.Empty do
				buffer.writeu8(SendBuffer, Allocate(1), Item)
			end
			buffer.writeu8(SendBuffer, Allocate(1), #Value.Deep.Complex)
			for _, Item in Value.Deep.Complex do
				buffer.writeu8(SendBuffer, Allocate(1), Item)
			end
			Types.WriteUnitVector(Value.Deep.Vector)
		end
	end
end

function Types.ReadEntity(): Entity
	local Value: Entity;
	if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
		Value = {} :: any
		if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
			Value.Identifier = buffer.readu8(RecieveBuffer, Read(1))
		end
		Value.Health = Types.ReadHealth()
		if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
			local Index = buffer.readu8(RecieveBuffer, Read(1))
			if Index == 0 then
				Value.LocalState = "Replicated"
			elseif Index == 1 then
				Value.LocalState = "Unreplicated"
			else
				error(`Unexpected enum: {Value.LocalState}`)
			end
		end
		Value.Character = Types.ReadState()
		Value.Direction = Types.ReadUnitVector()
		if buffer.readu8(RecieveBuffer, Read(1)) == 1 then
			Value.Deep = {} :: any
			Value.Deep.Empty = table.create(0)
			local Length = buffer.readu8(RecieveBuffer, Read(1))
			assert(Length >= 1)
			assert(Length <= 12)
			Value.Deep.Complex = table.create(Length)
			for Index = 1, Length do
				local Item = buffer.readu8(RecieveBuffer, Read(1))
				table.insert(Value.Deep.Complex, Item)
			end
			Value.Deep.Vector = Types.ReadUnitVector()
		end
	end
	return Value
end

function Types.WritePACKET_ServerReliable(Value: Entity)
	buffer.writeu8(SendBuffer, Allocate(1), 0)
	Types.WriteEntity(Value)
end

function Types.ReadPACKET_ServerReliable(): Entity
	return Types.ReadEntity()
end

function Types.WritePACKET_ServerUnreliable(Value: Entity)
	buffer.writeu8(SendBuffer, Allocate(1), 0)
	Types.WriteEntity(Value)
end

function Types.ReadPACKET_ServerUnreliable(): Entity
	return Types.ReadEntity()
end

function Types.WritePACKET_ClientReliable(Value: Entity)
	buffer.writeu8(SendBuffer, Allocate(1), 1)
	Types.WriteEntity(Value)
end

function Types.ReadPACKET_ClientReliable(): Entity
	return Types.ReadEntity()
end

function Types.WritePACKET_ClientUnreliable(Value: Entity)
	buffer.writeu8(SendBuffer, Allocate(1), 1)
	Types.WriteEntity(Value)
end

function Types.ReadPACKET_ClientUnreliable(): Entity
	return Types.ReadEntity()
end

function Types.WritePACKET_Custom(Value: {number})
	buffer.writeu8(SendBuffer, Allocate(1), 2)
	for _, Item in Value do
		buffer.writeu8(SendBuffer, Allocate(1), Item)
	end
end

function Types.ReadPACKET_Custom(): {number}
	local Value: {number};
	Value = table.create(1)
	for Index = 1, 1 do
		local Item = buffer.readu8(RecieveBuffer, Read(1))
		table.insert(Value, Item)
	end
	return Value
end

local PlayersMap: {[Player]: {Cursor: number, Buffer: buffer}} = {}

Players.PlayerAdded:Connect(function(Player)
    PlayersMap[Player] = {
        Cursor = 0,
        Buffer = buffer.create(64)
    }
end)

Players.PlayerRemoving:Connect(function(Player)
    PlayersMap[Player] = {
        Cursor = 0,
        Buffer = buffer.create(64)
    }
end)

local function StepReplication()
    for Player, Send in PlayersMap do
        if Send.Cursor <= 0 then
            continue
        end

        local Buffer = buffer.create(Send.Cursor)
        buffer.copy(Buffer, 0, Send.Buffer, 0, Send.Cursor)
        Reliable:FireClient(Player, Buffer)

        Send.Cursor = 0
        buffer.fill(Send.Buffer, 0, 0)
    end
end



Reliable.OnServerEvent:Connect(function(Player: Player, Buffer: buffer)
	RecieveCursor = 0
	RecieveBuffer = Buffer
	local Size = buffer.len(RecieveBuffer)
	while RecieveCursor < Size do
		local Index = buffer.readu8(RecieveBuffer, Read(1))
		if Index == 1 then
			local Value = Types.ReadPACKET_ClientReliable()
			if Events.Reliable[1] then
				Events.Reliable[1](Player, Value)
			else
				if not Queue.Reliable[1] then Queue.Reliable[1] = {} end
				table.insert(Queue.Reliable[1], {Player, Value})
			end
		end
	end
end)

Unreliable.OnServerEvent:Connect(function(Player: Player, Buffer: buffer)
	RecieveCursor = 0
	RecieveBuffer = Buffer
	local Size = buffer.len(RecieveBuffer)
	while RecieveCursor < Size do
		local Index = buffer.readu8(RecieveBuffer, Read(1))
		if Index == 1 then
			local Value = Types.ReadPACKET_ClientUnreliable()
			if Events.Unreliable[1] then
				Events.Unreliable[1](Player, Value)
			else
				if not Queue.Unreliable[1] then Queue.Unreliable[1] = {} end
				table.insert(Queue.Unreliable[1], {Player, Value})
			end
		elseif Index == 2 then
			local Value = Types.ReadPACKET_Custom()
			if Events.Unreliable[2] then
				Events.Unreliable[2](Player, Value)
			else
				if not Queue.Unreliable[2] then Queue.Unreliable[2] = {} end
				table.insert(Queue.Unreliable[2], {Player, Value})
			end
		end
	end
end)

return {
	StepReplication = StepReplication,
	ServerReliable = {
		Fire = function(Player: Player, Value: Entity)
			Load(PlayersMap[Player])
			Types.WritePACKET_ServerReliable(Value)
			PlayersMap[Player] = Save()
		end,
		FireAll = function(Value: Entity)
			Load()
			Types.WritePACKET_ServerReliable(Value)
			for _, Player in Players:GetPlayers() do
				PlayersMap[Player] = Save()
			end
		end,
		FireList = function(List: {Player}, Value: Entity)
			Load()
			Types.WritePACKET_ServerReliable(Value)
			for _, Player in List do
				PlayersMap[Player] = Save()
			end
		end,
		FireExcept = function(Except: Player, Value: Entity)
			Load()
			Types.WritePACKET_ServerReliable(Value)
			for _, Player in Players:GetPlayers() do
				if Player == Except then continue end
				PlayersMap[Player] = Save()
			end
		end
	},
	ServerUnreliable = {
		Fire = function(Player: Player, Value: Entity)
			Load()
			Types.WritePACKET_ServerUnreliable(Value)
			local Buffer = buffer.create(SendCursor)
			buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)
			Unreliable:FireClient(Player, Buffer)
		end,
		FireAll = function(Value: Entity)
			Load()
			Types.WritePACKET_ServerUnreliable(Value)
			local Buffer = buffer.create(SendCursor)
			buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)
			Unreliable:FireAllClients(Buffer)
		end,
		FireList = function(List: {Player}, Value: Entity)
			Load()
			Types.WritePACKET_ServerUnreliable(Value)
			local Buffer = buffer.create(SendCursor)
			buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)
			for _, Player in List do
				Unreliable:FireClient(Player, Buffer)
			end
		end,
		FireExcept = function(Except: Player, Value: Entity)
			Load()
			Types.WritePACKET_ServerUnreliable(Value)
			local Buffer = buffer.create(SendCursor)
			buffer.copy(Buffer, 0, SendBuffer, 0, SendCursor)
			for _, Player in Players:GetPlayers() do
				if Player == Except then continue end
				Unreliable:FireClient(Player, Buffer)
			end
		end
	},
	ClientReliable = {
		Listen = function(Listener: (Player, Entity) -> ())
			Events.Reliable[1] = Listener
			task.spawn(function()
				local Queue = Queue.Reliable[1] or {}
				Queue.Reliable[1] = nil
				for Index, Arguments in Queue do
					Listener(table.unpack(Arguments))
				end
			end)
		end
	},
	ClientUnreliable = {
		Listen = function(Listener: (Player, Entity) -> ())
			Events.Unreliable[1] = Listener
			task.spawn(function()
				local Queue = Queue.Unreliable[1] or {}
				Queue.Unreliable[1] = nil
				for Index, Arguments in Queue do
					Listener(table.unpack(Arguments))
				end
			end)
		end
	},
	Custom = {
		Listen = function(Listener: (Player, {number}) -> ())
			Events.Unreliable[2] = Listener
			task.spawn(function()
				local Queue = Queue.Unreliable[2] or {}
				Queue.Unreliable[2] = nil
				for Index, Arguments in Queue do
					Listener(table.unpack(Arguments))
				end
			end)
		end
	},
}