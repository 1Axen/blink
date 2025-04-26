--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function create(size: RValue<number>): Call<{any}>
    return projection.call(
        constant.from_value("table.create"), 
        {size}
    )
end

return table.freeze({
    create = create
})