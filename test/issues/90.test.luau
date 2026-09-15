local compiler = require("@compiler")
local environment_mock = require("@test/mock/environment_mock")
local luau = require("@lute/luau")
local write_targets = require("@test/utils/write_targets")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type TypesAPI = {
	exports: {
		[string]: {
			read: (buffer, number?) -> (any, number),
			write: (any) -> (buffer, number),
		},
	},
}

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	const targets = compiler.compile_contents(
		[[
		@export
		type health = u8(0..100)
	]],
		{ profile = "test" }
	)
	const targets_path = write_targets("issue90", targets)

	const environment = environment_mock()
	const bytecode = luau.compile(targets.types)
	const types_module = luau.load(bytecode, tostring(targets_path.types), environment)() :: TypesAPI

	test("#90 numeral bounds are properly enforced", function()
		expect(pcall(types_module.exports.health.write, 100)).is_true()
		expect(pcall(types_module.exports.health.write, 101)).never_is_true()
	end)
end
