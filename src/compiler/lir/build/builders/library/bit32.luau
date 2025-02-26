--!strict

local lir = require("@structures/lir")

local constant = require("@builders/constant")
local projection = require("@builders/projection")

type Call<T> = lir.ProjCall<T>
type RValue<T> = lir.RValue<T>

local function bor(...: RValue<number>): Call<number>
    return projection.call(
        constant.from_value("bit32.bor"),
        {...} :: {RValue<any>}
    )
end

local function lshift(x: RValue<number>, disp: lir.Constant<number>): Call<number>
    return projection.call(
        constant.from_value("bit32.lshift"),
        {x, disp} :: {RValue<any>}
    )
end

local function rshift(x: RValue<number>, disp: lir.Constant<number>): Call<number>
    return projection.call(
        constant.from_value("bit32.rshift"),
        {x, disp} :: {RValue<any>}
    )
end

return table.freeze({
    bor = bor,
    lshift = lshift,
    rshift = rshift,
})