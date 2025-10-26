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

local function move<T>(
	source: RValue<{ T }>,
	from: RValue<number>,
	to: RValue<number>,
	at: RValue<number>,
	destination: RValue<{ T }>
)
	return projection.call(constant.from_value("table.move"), { source, from, to, at, destination })
end

local function find<T>(target: RValue<{ T }>, value: RValue<any>, start_at: RValue<number>?): Call<number?>
	return projection.call(constant.from_value("table.find"), { target, value, start_at :: any })
end

local function clear<T>(target: RValue<{ T }>)
	return projection.call(constant.from_value("table.clear"), { target })
end

return table.freeze({
	create = create,
	insert = insert,
	find = find,
	move = move,
	clear = clear,
})
