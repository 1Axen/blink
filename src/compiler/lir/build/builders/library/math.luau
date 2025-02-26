--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function cos(n: RValue<number>): Call<number>
    return projection.call(
        constant.from_value("math.cos"), 
        {n} :: {RValue<any>}
    )
end

local function sin(n: RValue<number>): Call<number>
    return projection.call(
        constant.from_value("math.sin"), 
        {n} :: {RValue<any>}
    )
end

return table.freeze({
    cos = cos,
    sin = sin
})