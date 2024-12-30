--!strict

local lir = require("@compiler/structures/lir")

type LValue = lir.LValue
type UnaryLen = lir.UnaryLen

local function unary_len(of: LValue): UnaryLen
    return {
        kind = "len",
        of = of
    }
end

return table.freeze({
    len = unary_len,
})