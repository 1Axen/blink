--!strict

local types = require("@lir/types")

local function unary_len(of: types.RValue<any>): types.UnaryLen<number>
	return {
		__phantom_type = nil :: any,
		type = "unary",
		kind = "len",
		of = of :: any,
	}
end

return table.freeze({
	len = unary_len,
})
