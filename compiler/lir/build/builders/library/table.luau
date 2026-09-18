--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = types.ProjCall<T>
type Readable<T> = types.Readable<T>

local function create(size: Readable<number>): Call<{ any }>
	return projection.call(constant.from_value("table.create"), { size })
end

local function insert<T>(into: Readable<{ T }>, value: Readable<T>)
	return projection.call(constant.from_value("table.insert"), { into, value })
end

local function move<T>(
	source: Readable<{ T }>,
	from: Readable<number>,
	to: Readable<number>,
	at: Readable<number>,
	destination: Readable<{ T }>
)
	return projection.call(constant.from_value("table.move"), { source, from, to, at, destination })
end

local function find<T>(target: Readable<{ T }>, value: Readable<any>, start_at: Readable<number>?): Call<number?>
	return projection.call(constant.from_value("table.find"), { target, value, start_at :: Readable<number> })
end

local function clear<T>(target: Readable<{ T }>)
	return projection.call(constant.from_value("table.clear"), { target })
end

local function clone<T>(target: Readable<{ T }>)
	return projection.call(constant.from_value("table.clone"), { target })
end

const function remove<T>(target: Readable<{ T }>, index: Readable<number>?): Call<T?>
	return projection.call(constant.from_value("table.remove"), { target, index :: Readable<any> })
end

return table.freeze({
	create = create,
	insert = insert,
	remove = remove,
	find = find,
	move = move,
	clear = clear,
	clone = clone,
})
