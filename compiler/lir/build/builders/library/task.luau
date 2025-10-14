--!strict

local lir = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function spawn(fn: RValue<any>, args: { RValue<any> }): Call<{ any }>
	args = table.clone(args)
	table.insert(args, 1, fn)
	return projection.call(constant.from_value("task.spawn"), args)
end

return table.freeze({
	spawn = spawn,
})
