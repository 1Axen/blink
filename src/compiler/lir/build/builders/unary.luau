--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type UnaryLen = lir.UnaryLen

local function unary_len(of: RValue): UnaryLen
    return {
        type = "unary",
        kind = "len",
        of = of
    }
end

return table.freeze({
    len = unary_len,
})