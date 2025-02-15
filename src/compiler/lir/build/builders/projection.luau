--!strict

local lir = require("@structures/lir")

type ProjCall = lir.ProjCall
type ProjField = lir.ProjField
type ProjIndex = lir.ProjIndex
type ProjNamecall = lir.ProjNamecall

type RValue = lir.RValue
type LValue = lir.LValue
type Constant<T> = lir.Constant<T>
type Register = lir.RegisterId

local function proj_call(base: LValue | Constant<string>, args: {RValue}): ProjCall
    return {
        type = "projection",
        kind = "call",
        base = base,
        args = args,
    }
end

local function proj_field(base: LValue | Constant<string>, field: RValue): ProjField
    return {
        type = "projection",
        kind = "field",
        base = base,
        field = field,
    }
end

local function proj_index(base: LValue | Constant<string>, element: lir.Constant<string>): ProjIndex
    return {
        type = "projection",
        kind = "index",
        base = base,
        element = element,
    }
end

local function proj_namecall(base: LValue | Constant<string>, method: Constant<string>, args: {RValue}): ProjNamecall
    return {
        type = "projection",
        kind = "namecall",
        base = base,
        method = method,
        args = args,
    }
end

return table.freeze({
    call = proj_call,
    field = proj_field,
    index = proj_index,
    namecall = proj_namecall
})