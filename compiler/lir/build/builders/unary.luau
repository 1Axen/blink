--!strict

local lir = require("@lir/types")

local function unary_len(of: lir.RValue<any>): lir.UnaryLen<number>
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
