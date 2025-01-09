--!strict

local lir = require("@compiler/structures/lir")

type ProjCall = lir.ProjCall
type ProjField = lir.ProjField
type ProjIndex = lir.ProjIndex

type LValue = lir.LValue
type Register = lir.RegisterId

local function proj_call(base: LValue, args: {lir.Value}): ProjCall
    return {
        kind = "call",
        base = base,
        args = args,
    }
end

local function proj_field(base: LValue, field: LValue): ProjField
    return {
        kind = "field",
        base = base,
        field = field,
    }
end

local function proj_index(base: LValue, element: lir.Constant<string>): ProjIndex
    return {
        kind = "index",
        base = base,
        element = element,
    }
end

return table.freeze({
    call = proj_call,
    field = proj_field,
    index = proj_index
})