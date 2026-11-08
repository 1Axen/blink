local compiler = require("@compiler")

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

	test("multiple references to type in discriminated union", function()
		expect(function()
			compiler.compile_contents(
				[[
				type foo = u8
				type bar = union "kind" {
					first {
						value: foo,
					},
					second {
						value: foo
					}
				}
				]],
				{ profile = "test" }
			)
		end).never_fails()
	end)
end
