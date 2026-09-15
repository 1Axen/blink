local data_model_mock = require("@test/mock/data_model_mock")

const function setup_server()
	return data_model_mock.create_data_model("Server")
end

return setup_server
