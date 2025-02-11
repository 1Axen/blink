--!strict

local lir = require("@structures/lir")

type Call = lir.StatCall
type Assign = lir.StatAssign
type MultiAssign = lir.StatMultiAssign

type RValue = lir.RValue
type Register = lir.RegisterId

local function stat_call(call: lir.ProjCall): Call
    return {
        kind = "call",
        call = call
    }
end

local function stat_assign(into: lir.LValue, value: RValue?): Assign
    return {
        kind = "assign",
        into = into,
        value = value
    }
end

local function stat_multi_assign(into: {lir.LValue}, value: RValue?): MultiAssign
    return {
        kind = "multi_assign",
        into = into,
        value = value
    }
end

return table.freeze({
    call = stat_call,
    assign = stat_assign,
    multi_assign = stat_multi_assign
})