local panic = require("@util/panic")
local types = require("./types")

type Lir = types.Lir
type FnId = types.FnId
type Fn = types.Fn

local function fn_from_id(lir: Lir, fn_id: FnId): Fn
	local fn = lir.fn_map[fn_id]
	if fn == nil then
		return panic("Expected fn id to point to a fn")
	end

	return fn
end

return table.freeze({
	fn_from_id = fn_from_id,
})
