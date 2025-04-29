--!strict

local lir = require("@lir/types")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

type Axis = lir.RValue<number>

local function create(x: Axis, y: Axis, z: Axis): Call<vector>
    return projection.call(
        constant.from_value("vector.create"), 
        {x, y, z}
    )
end

local function magnitude(vec: lir.RValue<vector>): Call<number>
    return projection.call(
        constant.from_value("vector.magnitude"), 
        {vec}
    )
end

return table.freeze({
    create = create,
    magnitude = magnitude,
})