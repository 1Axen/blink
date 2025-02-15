--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type Condition = lir.Condition

local function ternary(cond: Condition, left: RValue, right: RValue): lir.Ternary
    return {
        type = "ternary",
        cond = cond,
        left = left,
        right = right
    }
end

return ternary