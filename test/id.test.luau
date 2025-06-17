type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lune").configure({}))

return function(tiniest: Tiniest)
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	local id = require("@compiler/id")

	describe("methods", function()
		local flags = { id.TY_FLAG, id.DECL_FLAG, id.NODE_FLAG, id.SCOPE_FLAG }

		test("getters", function()
			for _, flag in flags do
				local file = math.random(0, 2 ^ 7 - 1)
				local index = math.random(0, 2 ^ 22 - 1)
				local test_id: id.Id = (flag + (file * 2 ^ 3) + (index * 2 ^ 10)) :: any

				expect(id.type(test_id)).is(flag)
				expect(id.file(test_id)).is(file)
				expect(id.index(test_id)).is(index)
			end
		end)

		test("constructor", function()
			local file = math.random(0, 2 ^ 7 - 1)
			local index = math.random(0, 2 ^ 22 - 1)
			local node_id = id.node_id.create(file, index)

			expect(id.type(node_id)).is(id.NODE_FLAG)
			expect(id.file(node_id)).is(file)
			expect(id.index(node_id)).is(index)
		end)

		test("conversion", function()
			local file = math.random(0, 2 ^ 7 - 1)
			local index = math.random(0, 2 ^ 22 - 1)

			local node_id = id.node_id.create(file, index)
			local ty_id = id.to_ty_id(node_id)
			local decl_id = id.to_decl_id(node_id)
			local scope_id = id.to_scope_id(node_id)

			expect(id.type(ty_id)).is(id.TY_FLAG)
			expect(id.type(decl_id)).is(id.DECL_FLAG)
			expect(id.type(scope_id)).is(id.SCOPE_FLAG)
		end)
	end)
end
