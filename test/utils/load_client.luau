local data_model_mock = require("@test/mock/data_model_mock")
local environment_mock = require("@test/mock/environment_mock")
local luau = require("@lute/luau")

type DataModelMock = data_model_mock.DataModelMock

type ClientAPI = {
	exports: {
		[string]: {
			fire: (...any) -> (),
			on: ((...any) -> ()) -> () -> (),
			iter: () -> () -> (number, ...any),
			invoke: (...any) -> ...any,
		},
	},
	step_replication: () -> (),
}

const function load_client(
	server_data_model: DataModelMock,
	client_data_model: DataModelMock,
	source: string,
	chunkname: string
)
	const server_replicated_storage = server_data_model:GetService("ReplicatedStorage")
	const reliable_event = assert(server_replicated_storage:FindFirstChildOfClass("RemoteEvent"))
	const unreliable_event = assert(server_replicated_storage:FindFirstChildOfClass("UnreliableRemoteEvent"))
	data_model_mock.replicate_instance(reliable_event, server_data_model, client_data_model)
	data_model_mock.replicate_instance(unreliable_event, server_data_model, client_data_model)

	const bytecode = luau.compile(source)
	const environment = environment_mock(client_data_model)
	return luau.load(bytecode, chunkname, environment)() :: ClientAPI
end

return load_client
