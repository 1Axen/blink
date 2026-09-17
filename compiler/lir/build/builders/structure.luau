--!strict

local types = require("@lir/types")

type RValue<T> = types.RValue<T>
type Readable<T = any> = types.Readable<T>
type Constant<T> = types.Constant<T>

type StructureMap<T = any> = types.Map<T>
type StructureArray<T = any> = types.Array<T>
type StructureStruct<T = any> = types.Struct<T>

local function structure_map(values: { read [Readable<any>]: Readable<any> }): StructureMap<any>
	return {
		__readable = nil :: any,
		type = "structure",
		kind = "map",
		values = values :: { [RValue<any>]: RValue<any> },
	}
end

local function structure_array<T>(values: { read Readable<T> }): StructureArray<T>
	return {
		__readable = nil :: any,
		type = "structure",
		kind = "array",
		values = values :: { RValue<T> },
	}
end

local function structure_struct<T>(values: { read [Constant<string>]: Readable<T> }): StructureStruct<T>
	return {
		__readable = nil :: any,
		type = "structure",
		kind = "struct",
		values = values :: { [Constant<string>]: RValue<T> },
	}
end

return table.freeze({
	map = structure_map,
	array = structure_array,
	struct = structure_struct,
})
