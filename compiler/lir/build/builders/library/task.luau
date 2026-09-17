--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Readable<T> = types.Readable<T>
type ProjCall<T> = types.ProjCall<T>

local function spawn(fn: Readable<any>, args: { read Readable<any> }): ProjCall<thread>
	return projection.call(constant.from_value("task.spawn"), { fn, unpack(args :: { Readable<any> }) })
end

return table.freeze({
	spawn = spawn,
})
