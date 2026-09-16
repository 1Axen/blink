--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Readable<T> = types.Readable<T>
type ProjCall<T> = types.ProjCall<T>

local function spawn(fn: Readable<any>, args: { Readable<any> }): ProjCall<thread>
	args = table.clone(args)
	table.insert(args, 1, fn)
	return projection.call(constant.from_value("task.spawn"), args)
end

return table.freeze({
	spawn = spawn,
})
