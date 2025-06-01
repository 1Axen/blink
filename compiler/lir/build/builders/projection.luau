--!strict

local lir = require("@lir/types")

type ProjCall<T> = lir.ProjCall<T>
type ProjField<T> = lir.ProjField<T>
type ProjIndex<T> = lir.ProjIndex<T>
type ProjNamecall<T> = lir.ProjNamecall<T>

type RValue<T> = lir.RValue<T>
type Constant<T> = lir.Constant<T>

type Base = lir.LValue<any> | Constant<string>

local function proj_call<T>(base: Base, args: { RValue<T> }): any
	return {
		__phantom_type = nil :: any,
		type = "projection",
		kind = "call",
		base = base,
		args = args,
	}
end

local function proj_field<T>(base: Base, field: RValue<T>): any
	return {
		__phantom_type = nil :: any,
		type = "projection",
		kind = "field",
		base = base,
		field = field,
	}
end

local function proj_index<T>(base: Base, element: lir.Constant<string>): any
	return {
		__phantom_type = nil :: any,
		type = "projection",
		kind = "index",
		base = base,
		element = element,
	}
end

local function proj_namecall<T>(base: Base, method: Constant<string>, args: { RValue<T> }): any
	return {
		__phantom_type = nil :: any,
		type = "projection",
		kind = "namecall",
		base = base,
		method = method,
		args = args,
	}
end

return table.freeze({
	call = proj_call,
	field = proj_field,
	index = proj_index,
	namecall = proj_namecall,
})
