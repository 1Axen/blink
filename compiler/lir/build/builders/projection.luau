--!strict

local types = require("@lir/types")

type Readable<T> = types.Readable<T>
type Constant<T> = types.Constant<T>

type Base = types.Writeable<any> | Constant<string>

local function proj_call(base: Base, args: { read Readable<any> }): any
	return {
		__readable = nil :: any,
		__callable = nil :: any,
		type = "projection",
		kind = "call",
		base = base,
		args = args,
	}
end

local function proj_field(base: Base, field: Readable<any>): any
	return {
		__readable = nil :: any,
		__writeable = nil :: any,
		type = "projection",
		kind = "field",
		base = base,
		field = field,
	}
end

local function proj_index(base: Base, element: types.Constant<string>): any
	return {
		__readable = nil :: any,
		__writeable = nil :: any,
		type = "projection",
		kind = "index",
		base = base,
		element = element,
	}
end

local function proj_namecall(base: Base, method: Constant<string>, args: { read Readable<any> }): any
	return {
		__readable = nil :: any,
		__callable = nil :: any,
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
