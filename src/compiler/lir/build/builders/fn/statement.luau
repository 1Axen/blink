--!strict

local lir = require("@structures/lir")

type Call = lir.StatCall
type Assign = lir.StatAssign
type Remark = lir.StatRemark
type MultiAssign = lir.StatMultiAssign

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function stat_call(call: lir.ProjCall): Call
    return {
        kind = "call",
        call = call
    }
end

local function stat_assign(into: LValue, value: RValue?): Assign
    return {
        kind = "assign",
        into = into,
        value = value
    }
end

local function stat_remark(text: string): Remark
    return {
        kind = "remark",
        text = text
    }
end

local function stat_multi_assign(into: {LValue}, value: RValue): MultiAssign
    return {
        kind = "multi_assign",
        into = into,
        value = value
    }
end

return table.freeze({
    call = stat_call,
    remark = stat_remark,
    assign = stat_assign,
    multi_assign = stat_multi_assign
})