local id = require("@compiler/id")
local tesk_kit = require("@vendor/test_kit")

local TEST, CASE, SKIP, FOCUS, expect = tesk_kit.test()

TEST("compiler ids", function()
    local flags = {id.TY_FLAG, id.DECL_FLAG, id.NODE_FLAG, id.SCOPE_FLAG}

    CASE("getters", function()
        local flag = flags[math.random(1, #flags)]
        local file = math.random(0, 2^7 - 1)
        local index = math.random(0, 2^22 - 1)
        
        local example_id: id.Id = (flag + (file * 2^3) + (index * 2^10)) :: any

        expect(id.type(example_id)).to_equal(flag)
        expect(id.file(example_id)).to_equal(file)
        expect(id.index(example_id)).to_equal(index)
    end)

    CASE("constructor", function()
        local file = math.random(0, 2^7 - 1)
        local index = math.random(0, 2^22 - 1)
        local node_id = id.node_id.create(file, index)

        expect(id.type(node_id)).to_equal(id.NODE_FLAG)
        expect(id.file(node_id)).to_equal(file)
        expect(id.index(node_id)).to_equal(index)
    end)

    CASE("conversion", function()
        local file = math.random(0, 2^7 - 1)
        local index = math.random(0, 2^22 - 1)

        local node_id = id.node_id.create(file, index)
        local ty_id = id.to_ty_id(node_id)
        local decl_id = id.to_decl_id(node_id)
        local scope_id = id.to_scope_id(node_id)

        expect(id.type(ty_id)).to_equal(id.TY_FLAG)
        expect(id.type(decl_id)).to_equal(id.DECL_FLAG)
        expect(id.type(scope_id)).to_equal(id.SCOPE_FLAG)
    end)
end)

return nil