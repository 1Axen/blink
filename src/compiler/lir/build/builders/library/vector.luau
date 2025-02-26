--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

type Axis = lir.Constant<number> | lir.RegisterId<number>

local function create(x: Axis, y: Axis, z: Axis): Call<vector>
    return projection.call(
        constant.from_value("vector.create"), 
        {x, y, z} :: {RValue<any>}
    )
end

local function magnitude(vec: lir.Id<vector>): Call<number>
    return projection.call(
        constant.from_value("vector.magnitude"), 
        {vec} :: {RValue<any>}
    )
end

return table.freeze({
    create = create,
    magnitude = magnitude,
})