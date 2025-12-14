--!strict

local ty = require("@ty")
local types = require("@lir/types")

type RValue<T> = types.RValue<T>

local function cast_ty<T>(value: RValue<T>, cast_to: ty.Ty): types.TyCast<T>
	return {
		__phantom_type = nil :: any,

		type = "cast",
		kind = "ty",
		value = value,
		cast_to = cast_to,
	}
end

local function cast_static<T>(value: RValue<T>, cast_to: string): types.StaticCast<T>
	return {
		__phantom_type = nil,
		type = "cast",
		kind = "static",
		value = value,
		cast_to = cast_to,
	}
end

return table.freeze({
	ty = cast_ty,
	static = cast_static,
})
