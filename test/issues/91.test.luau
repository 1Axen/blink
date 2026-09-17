local compiler = require("@compiler")
local playtest_solo = require("@test/utils/playtest_solo")
local write_targets = require("@test/utils/write_targets")
type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	const targets = compiler.compile_contents(
		[[
		event reliable = {from: Client, type: Reliable, call: SingleSync, data: u8}
		event unreliable = {from: Client, type: Unreliable, call: SingleSync, data: u8}
	]],
		{ profile = "test" }
	)
	const targets_path = write_targets("issue91", targets)

	test("#91 client event write errors are caught and undone", function()
		const server_module, client_module = playtest_solo(targets, targets_path)

		local n_reliables_received = 0
		local n_unreliable_received = 0

		server_module.exports.reliable.on(function()
			n_reliables_received += 1
		end)
		server_module.exports.unreliable.on(function(...)
			n_unreliable_received += 1
		end)

		expect(function()
			-- valid data
			client_module.exports.reliable.fire(255)
			client_module.exports.unreliable.fire(255)
		end).never_fails()

		expect(function()
			-- invalid data, should be skipped
			client_module.exports.reliable.fire("text")
			client_module.exports.unreliable.fire("text")
		end).fails()

		expect(function()
			-- valid data
			client_module.exports.reliable.fire(255)
			client_module.exports.unreliable.fire(255)
		end).never_fails()

		server_module.step_replication()
		client_module.step_replication()

		expect(n_reliables_received).is(2)
		expect(n_unreliable_received).is(2)
	end)
end
