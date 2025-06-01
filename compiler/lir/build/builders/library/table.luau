--!strict

local lir = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function create(size: RValue<number>): Call<{ any }>
	return projection.call(constant.from_value("table.create"), { size })
end

local function insert<T>(into: RValue<{ T }>, value: RValue<T>)
	return projection.call(constant.from_value("table.insert"), { into, value })
end

return table.freeze({
	create = create,
	insert = insert,
})
