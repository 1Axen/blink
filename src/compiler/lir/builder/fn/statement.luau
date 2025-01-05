--!strict

local lir = require("@compiler/structures/lir")

type Call = lir.StatCall
type Assign = lir.StatAssign

type Value = lir.Value
type Register = lir.RegisterId

local function stat_call(call: lir.ProjCall): Call
    return {
        kind = "call",
        call = call
    }
end

local function stat_assign(into: Register, value: Value?): Assign
    return {
        kind = "assign",
        into = into,
        value = value
    }
end

return table.freeze({
    call = stat_call,
    assign = stat_assign
})