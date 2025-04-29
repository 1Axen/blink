--!strict

local lir = require("@lir/types")

type RValue<T = any> = lir.RValue<T>
type Constant<T> = lir.Constant<T>

type StructureMap<T = any> = lir.Map<T>
type StructureArray<T = any> = lir.Array<T>
type StructureStruct<T = any> = lir.Struct<T>

local function structure_map(values: {[RValue<any>]: RValue<any>}): StructureMap<any>
    return {
        __phantom_type = nil :: any,
        
        type = "structure",
        kind = "map",
        values = values
    }
end

local function structure_array<T>(values: {RValue<T>}): StructureArray<T>
    return {
        __phantom_type = nil :: any,
        
        type = "structure",
        kind = "array",
        values = values
    }
end

local function structure_struct<T>(values: {[Constant<string>]: RValue<T>}): StructureStruct<T>
    return {
        __phantom_type = nil :: any,

        type = "structure",
        kind = "struct",
        values = values
    }
end

return table.freeze({
    map = structure_map,
    array = structure_array,
    struct = structure_struct,
})