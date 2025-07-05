type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lune").configure({}))

return function(tiniest: Tiniest)
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	local id = require("@compiler/id")

	describe("methods", function()
		test("getters", function()
			local file = math.random(0, 2 ^ 7 - 1)
			local index = math.random(0, 2 ^ 22 - 1)
			local test_id: id.Id = file + (index * 2 ^ 8)

			expect(id.file(test_id)).is(file)
			expect(id.index(test_id)).is(index)
		end)

		test("constructor", function()
			local file = math.random(0, 2 ^ 7 - 1)
			local index = math.random(0, 2 ^ 22 - 1)
			local example_id = id.create(file, index)
			expect(id.file(example_id)).is(file)
			expect(id.index(example_id)).is(index)
		end)
	end)
end
