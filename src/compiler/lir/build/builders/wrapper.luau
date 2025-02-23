--!strict

local lir = require("@structures/lir")

type RValue<T = any> = lir.RValue<T>
type WrapTable<T = any> = lir.WrapTable<T>
type WrapSingle<T = any> = lir.WrapSingle<T>

local function wrap_table<T>(values: {RValue<T>}): WrapTable<{T}>
    return {
        __phantom_type = nil :: any,
        
        type = "wrapper",
        kind = "table",
        values = values
    }
end

local function wrap_single<T>(value: RValue<T>): WrapSingle<T>
    return {
        __phantom_type = nil :: any,

        type = "wrapper",
        kind = "single",
        value = value
    }
end

return table.freeze({
    table = wrap_table,
    single = wrap_single,
})