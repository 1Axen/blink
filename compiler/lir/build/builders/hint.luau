--!strict

local ty = require("@ty")
local types = require("@lir/types")

type Ty = ty.Ty
type RValue<T> = types.RValue<T>

local function hint_ty(tty: Ty): types.HintTy
	return {
		type = "hint",
		kind = "ty",
		ty = tty,
	}
end

local function hint_static(static: string): types.HintStatic
	return {
		type = "hint",
		kind = "static",
		static = static,
	}
end

local function hint_function(parameters: { types.Parameter }, returns: { types.Return }): types.HintFunction
	return {
		type = "hint",
		kind = "function",
		parameters = parameters,
		returns = returns,
	}
end

return table.freeze({
	ty = hint_ty,
	static = hint_static,
	funct = hint_function,
})
