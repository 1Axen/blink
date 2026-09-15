local load_client = require("./load_client")
local load_server = require("./load_server")
local path = require("@util/path")
local setup_client = require("./setup_client")
local setup_server = require("./setup_server")
local write_targets = require("./write_targets")

const function playtest_solo(targets: write_targets.Targets, targets_path: write_targets.Paths)
	const server_dm = setup_server()
	const server_module = load_server(server_dm, targets.server, path.to_string(targets_path.server))
	const client_dm, player = setup_client(server_dm)
	const client_module = load_client(server_dm, client_dm, targets.client, path.to_string(targets_path.client))
	return server_module, client_module, player
end

return playtest_solo
