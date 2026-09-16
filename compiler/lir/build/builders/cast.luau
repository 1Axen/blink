--!strict

local ty = require("@ty")
local types = require("@lir/types")

type RValue = types.RValue<any>
type Readable<T> = types.Readable<T>

local function cast_ty<T>(value: Readable<T>, cast_to: ty.Ty): types.CastTy<T>
	return {
		__readable = nil :: any,

		type = "cast",
		kind = "ty",
		value = value :: RValue,
		cast_to = cast_to,
	}
end

local function cast_static<T>(value: Readable<T>, cast_to: string): types.CastStatic<T>
	return {
		__readable = nil :: any,
		type = "cast",
		kind = "static",
		value = value :: RValue,
		cast_to = cast_to,
	}
end

return table.freeze({
	ty = cast_ty,
	static = cast_static,
})
