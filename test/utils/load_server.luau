local data_model_mock = require("@test/mock/data_model_mock")
local environment_mock = require("@test/mock/environment_mock")
local luau = require("@lute/luau")

type PlayerMock = data_model_mock.PlayerMock
type DataModelMock = data_model_mock.DataModelMock

export type ServerAPI = {
	exports: {
		[string]: {
			fire: (player: PlayerMock, ...any) -> (),
			fire_all: (...any) -> (),
			fire_list: (list: { PlayerMock }, ...any) -> (),
			fire_except: (player: PlayerMock, ...any) -> (),
			on: ((player: PlayerMock, ...any) -> ...any) -> () -> (),
			iter: () -> () -> (number, PlayerMock, ...any),
		},
	},
	step_replication: () -> (),
}

const function load_server(data_model: DataModelMock, source: string, chunkname: string)
	local bytecode = luau.compile(source)
	const environment = environment_mock(data_model)
	return luau.load(bytecode, chunkname, environment)() :: ServerAPI
end

return load_server
