local compiler = require("@compiler")
local load_client = require("@test/utils/load_client")
local load_server = require("@test/utils/load_server")
local setup_client = require("@test/utils/setup_client")
local setup_server = require("@test/utils/setup_server")
local write_targets = require("@test/utils/write_targets")
type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	const targets = compiler.compile_contents(
		[[
		event reliable = {from: Server, type: Reliable, call: SingleSync}
		event unreliable = {from: Server, type: Unreliable, call: SingleSync}
	]],
		{ profile = "test" }
	)
	const targets_path = write_targets("issue92", targets)

	const server_dm = setup_server()
	const client_dm, player = setup_client(server_dm)
	const server_module = load_server(server_dm, targets.server, tostring(targets_path.server))
	const client_module = load_client(server_dm, client_dm, targets.client, tostring(targets_path.client))

	test("early player can still be fired #92", function()
		local reliable_received = false
		local unreliable_received = false

		client_module.exports.reliable.on(function()
			reliable_received = true
		end)
		client_module.exports.unreliable.on(function(...)
			unreliable_received = true
		end)

		server_module.exports.reliable.fire(player)
		server_module.exports.unreliable.fire(player)

		server_module.step_replication()
		client_module.step_replication()

		expect(reliable_received).is(true)
		expect(unreliable_received).is(true)
	end)
end
