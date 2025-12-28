export type Context = "Client" | "Server"

local function counter()
	local index = 0
	return function()
		local current = index
		index += 1
		return current
	end
end

local USER_ID_COUNTER = counter()
local EVENT_ID_COUNTER = counter()

type Listener<T...> = (T...) -> ()

local signal_class = {}
signal_class.__index = signal_class

type Signal<T...> = {
	read listeners: { Listener<T...> },
	read Fire: (Signal<T...>, T...) -> (),
	read Connect: (Signal<T...>, listener: Listener<T...>) -> (),
}

local function create_signal<T...>(): Signal<T...>
	local function fire<T...>(self: Signal<T...>, ...: T...)
		for _, listener in self.listeners do
			listener(...)
		end
	end

	local function connect(self: Signal<T...>, listener: Listener<T...>)
		table.insert(self.listeners, listener)
	end

	return table.freeze({
		listeners = {},
		Fire = fire,
		Connect = connect,
	})
end

local instance_class = {}
instance_class.__index = instance_class

export type InstanceMock = setmetatable<{
	Name: string,
	Parent: InstanceMock?,
	read ClassName: string,
	read children: { InstanceMock },
}, typeof(instance_class)>

function instance_class.__newindex(self: InstanceMock, key: any, value: any)
	if key == "Parent" then
		local parent = value :: InstanceMock
		table.insert(parent.children, self)
	end

	rawset(self :: any, key, value)
end

function instance_class.IsA(self: InstanceMock, class_name: string)
	if class_name == "Instance" then
		return true
	end

	return self.ClassName == class_name
end

function instance_class.GetChildren(self: InstanceMock): { InstanceMock }
	return table.clone(self.children)
end

function instance_class.WaitForChild(self: InstanceMock, name: string): InstanceMock?
	local child = self:FindFirstChild(name)
	if child == nil then
		warn('Infinite yield possible on "WaitForChild"')
		coroutine.yield()
	end

	return child
end

function instance_class.FindFirstChild(self: InstanceMock, name: string): InstanceMock?
	for _, child in self.children do
		if child.Name == name then
			return child
		end
	end

	return nil
end

function instance_class.FindFirstChildOfClass(self: InstanceMock, class_name: string): InstanceMock?
	for _, child in self.children do
		if child.ClassName == class_name then
			return child
		end
	end

	return nil
end

function instance_class.FindFirstAncestorOfClass(self: InstanceMock, class_name: string): InstanceMock?
	local ancestor = self.Parent
	while ancestor ~= nil do
		if ancestor.ClassName == class_name then
			break
		end

		ancestor = ancestor.Parent
	end

	return ancestor
end

local function create_instance(class_name: string, name: string?): InstanceMock
	return setmetatable({
		Name = name or class_name,
		ClassName = class_name,
		Parent = nil :: any,
		children = {},
	}, instance_class)
end

local player_class = setmetatable({}, instance_class)
player_class.__index = player_class
player_class.__newindex = instance_class.__newindex

export type PlayerMock =
	setmetatable<{
		UserId: number,
	}, typeof(player_class)>
	& InstanceMock

local function create_player(user_id: number?): PlayerMock
	local player = (setmetatable(create_instance("Player"), player_class) :: any) :: PlayerMock
	player.UserId = user_id or USER_ID_COUNTER()
	return player
end

local SERVER_EVENT = create_signal() :: Signal<number, number, ...any>
local CLIENT_EVENT = create_signal() :: Signal<number, number?, ...any>

local remote_event_class = setmetatable({}, instance_class)
remote_event_class.__index = remote_event_class
remote_event_class.__newindex = instance_class.__newindex

export type RemoteEventMock =
	setmetatable<{
		event_id: number,
		OnServerEvent: Signal<PlayerMock, ...any>,
		OnClientEvent: Signal<...any>,
	}, typeof(remote_event_class)>
	& InstanceMock

local function create_remote_event(class: "RemoteEvent" | "UnreliableRemoteEvent", event_id: number?): RemoteEventMock
	event_id = event_id or EVENT_ID_COUNTER()

	local on_server_event = create_signal() :: Signal<PlayerMock, ...any>
	local on_client_event = create_signal() :: Signal<...any>

	local remote_event = (setmetatable(create_instance(class), remote_event_class) :: any) :: RemoteEventMock
	remote_event.event_id = event_id
	remote_event.OnClientEvent = on_client_event
	remote_event.OnServerEvent = on_server_event

	CLIENT_EVENT:Connect(function(id: number, user_id, ...)
		local data_model = assert(remote_event:FindFirstAncestorOfClass("DataModel")) :: DataModelMock
		local players = data_model:GetService("Players") :: PlayersMock
		local local_player = players.LocalPlayer :: any?
		if local_player == nil then
			return
		end

		if id ~= event_id then
			return
		end

		if user_id and local_player.UserId ~= user_id then
			return
		end

		on_client_event:Fire(...)
	end)

	SERVER_EVENT:Connect(function(id: number, user_id, ...)
		local data_model = assert(remote_event:FindFirstAncestorOfClass("DataModel")) :: DataModelMock
		local players = data_model:GetService("Players") :: PlayersMock
		if players.LocalPlayer then
			return
		end

		if id ~= event_id then
			return
		end

		local player = players:GetPlayerByUserId(user_id)
		if player == nil then
			error(`Cannot find player with UserId: {user_id}`)
		end

		on_server_event:Fire(player, ...)
	end)

	return remote_event
end

function remote_event_class.FireServer(self: RemoteEventMock, ...)
	local data_model = assert(self:FindFirstAncestorOfClass("DataModel")) :: DataModelMock
	local players = data_model:GetService("Players") :: PlayersMock
	local local_player = assert(players.LocalPlayer, "Cannot call FireServer on the server")
	SERVER_EVENT:Fire(self.event_id, local_player.UserId, ...)
end

function remote_event_class.FireClient(self: RemoteEventMock, player: PlayerMock, ...)
	CLIENT_EVENT:Fire(self.event_id, player.UserId, ...)
end

function remote_event_class.FireAllClients(self: RemoteEventMock, ...)
	CLIENT_EVENT:Fire(self.event_id, nil, ...)
end

local run_service_class = setmetatable({}, instance_class)
run_service_class.__index = run_service_class
run_service_class.__newindex = instance_class.__newindex

export type RunServiceMock =
	setmetatable<{
		context: Context,
		Heartbeat: Signal<number>,
	}, typeof(run_service_class)>
	& InstanceMock

function run_service_class.IsEdit(self: RunServiceMock): boolean
	return self.context == "Edit"
end

function run_service_class.IsClient(self: RunServiceMock): boolean
	return self.context == "Client"
end

function run_service_class.IsServer(self: RunServiceMock): boolean
	return self.context == "Server"
end

local function create_run_service(context: Context): RunServiceMock
	local run_service = (setmetatable(create_instance("RunService"), run_service_class) :: any) :: RunServiceMock
	run_service.context = context
	run_service.Heartbeat = create_signal()
	return run_service
end

local players_class = setmetatable({}, instance_class)
players_class.__index = players_class
players_class.__newindex = instance_class.__newindex

export type PlayersMock =
	setmetatable<{
		LocalPlayer: PlayerMock?,
		PlayerAdded: Signal<PlayerMock>,
		PlayerRemoving: Signal<PlayerMock>,
	}, typeof(players_class)>
	& InstanceMock

function players_class.GetPlayerByUserId(self: PlayersMock, user_id: number): PlayerMock?
	for _, child in self:GetChildren() :: { PlayerMock } do
		if child:IsA("Player") and child.UserId == user_id then
			return child
		end
	end

	return nil
end

local function create_players(context: Context): PlayersMock
	local players = (setmetatable(create_instance("Players"), players_class) :: any) :: PlayersMock
	if context == "Client" then
		local local_player = create_player()
		local_player.Parent = players
		players.LocalPlayer = local_player
	end
	players.PlayerAdded = create_signal()
	players.PlayerRemoving = create_signal()
	return players
end

local data_model_class = setmetatable({}, instance_class)
data_model_class.__index = data_model_class

export type DataModelMock =
	setmetatable<{
		context: Context,
	}, typeof(data_model_class)>
	& InstanceMock

function data_model_class.GetService(self: InstanceMock, name: string): InstanceMock
	local existing = self:FindFirstChild(name)
	if existing then
		return existing
	end

	local service = create_instance(name)
	service.Name = name
	service.Parent = self
	return service
end

local function create_data_model(context: Context): DataModelMock
	local data_model = (setmetatable(create_instance("DataModel"), data_model_class) :: any) :: DataModelMock
	data_model.context = context
	create_run_service(context).Parent = data_model
	create_players(context).Parent = data_model
	return data_model
end

local function instance_new(class_name: string, parent: InstanceMock?): InstanceMock
	local instance: InstanceMock
	if class_name == "RemoteEvent" or class_name == "UnreliableRemoteEvent" then
		instance = create_remote_event(class_name)
	else
		instance = create_instance(class_name)
	end

	if parent then
		instance.Parent = parent
	end
	return instance
end

local function instance_from_existing(existing: InstanceMock): InstanceMock
	local clone: InstanceMock
	local class_name = existing.ClassName
	if class_name == "RemoteEvent" or class_name == "UnreliableRemoteEvent" then
		clone = create_remote_event(class_name, (existing :: RemoteEventMock).event_id)
	else
		clone = create_instance(class_name)
	end

	return clone
end

function connect_player(server: DataModelMock)
	local client = create_data_model("Client")
	local client_player = assert((client:GetService("Players") :: PlayersMock).LocalPlayer)

	local players = server:GetService("Players") :: PlayersMock
	local server_player = create_player(client_player.UserId)
	server_player.Parent = players
	players.PlayerAdded:Fire(server_player)

	return client, server_player
end

local function replicate_instance(instance: InstanceMock, from: DataModelMock, to: DataModelMock): InstanceMock
	local hierarchy: { InstanceMock } = { instance }
	do
		local ancestor = instance.Parent
		while ancestor and ancestor ~= from do
			table.insert(hierarchy, 1, ancestor)
			ancestor = ancestor.Parent
		end
	end

	local ancestor = to
	while true do
		local to_clone = table.remove(hierarchy, 1)
		if to_clone == nil then
			return ancestor
		end

		local name = to_clone.Name
		local existing = ancestor:FindFirstChild(name)
		if existing then
			ancestor = existing
			continue
		end

		local clone = instance_from_existing(to_clone)
		clone.Name = to_clone.Name
		clone.Parent = ancestor
		ancestor = clone
	end
end

return table.freeze({
	instance_new = instance_new,
	connect_player = connect_player,
	replicate_instance = replicate_instance,
	create_data_model = create_data_model,
	INSTANCE_METATABLE = instance_class,
})
