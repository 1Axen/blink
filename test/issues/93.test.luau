local compiler = require("@compiler")
local playtest_solo = require("@test/utils/playtest_solo")
local write_targets = require("@test/utils/write_targets")
type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	const targets = compiler.compile_contents(
		[[
		event reliable = {from: Client, type: Reliable, call: ManySync}
		event unreliable = {from: Client, type: Unreliable, call: ManySync}
	]],
		{ profile = "test" }
	)
	const targets_path = write_targets("issue91", targets)

	test("#93 event queue before first on is dumped on listener", function()
		const server_module, client_module = playtest_solo(targets, targets_path)

		local n_reliables_received = 0
		local n_unreliable_received = 0

		expect(function()
			client_module.exports.reliable.fire()
			client_module.exports.unreliable.fire()
		end).never_fails()

		server_module.step_replication()
		client_module.step_replication()

		-- make sure it's dumped only once
		for _ = 1, 2 do
			server_module.exports.reliable.on(function()
				n_reliables_received += 1
			end)
			server_module.exports.unreliable.on(function()
				n_unreliable_received += 1
			end)
		end

		expect(n_reliables_received).is(1)
		expect(n_unreliable_received).is(1)
	end)
end
