local data_model_mock = require("@test/mock/data_model_mock")

type DataModelMock = data_model_mock.DataModelMock

const function setup_client(server_data_model: DataModelMock)
	return data_model_mock.connect_player(server_data_model)
end

return setup_client
