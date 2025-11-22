--!strict

local types = require("@lir/types")

type RValue<T = any> = types.RValue<T>
type Constant<T> = types.Constant<T>

type StructureMap<T = any> = types.Map<T>
type StructureArray<T = any> = types.Array<T>
type StructureStruct<T = any> = types.Struct<T>

local function structure_map(values: { [RValue<any>]: RValue<any> }): StructureMap<any>
	return {
		__phantom_type = nil :: any,

		type = "structure",
		kind = "map",
		values = values,
	}
end

local function structure_array<T>(values: { RValue<T> }): StructureArray<T>
	return {
		__phantom_type = nil :: any,

		type = "structure",
		kind = "array",
		values = values,
	}
end

local function structure_struct<T>(values: { [Constant<string>]: RValue<T> }): StructureStruct<T>
	return {
		__phantom_type = nil :: any,

		type = "structure",
		kind = "struct",
		values = values,
	}
end

return table.freeze({
	map = structure_map,
	array = structure_array,
	struct = structure_struct,
})
