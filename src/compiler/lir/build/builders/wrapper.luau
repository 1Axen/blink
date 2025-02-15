--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type WrapTable = lir.WrapTable
type WrapSingle = lir.WrapSingle

local function wrap_table(values: {RValue}): WrapTable
    return {
        type = "wrapper",
        kind = "table",
        values = values
    }
end

local function wrap_single(value: RValue): WrapSingle
    return {
        type = "wrapper",
        kind = "single",
        value = value
    }
end

return table.freeze({
    table = wrap_table,
    single = wrap_single,
})