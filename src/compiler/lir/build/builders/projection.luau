--!strict

local lir = require("@structures/lir")

type ProjCall<T> = lir.ProjCall<T>
type ProjField<T> = lir.ProjField<T>
type ProjIndex<T> = lir.ProjIndex<T>
type ProjNamecall<T> = lir.ProjNamecall<T>

type RValue = lir.RValue<any>
type LValue = lir.LValue<any>
type Constant<T> = lir.Constant<T>

local function proj_call<T>(base: LValue | Constant<string>, args: {RValue}): ProjCall<any>
    return {
        __phantom_type = nil :: any,
        type = "projection",
        kind = "call",
        base = base,
        args = args,
    }
end

local function proj_field<T>(base: LValue | Constant<string>, field: RValue): ProjField<T>
    return {
        __phantom_type = nil :: any,
        type = "projection",
        kind = "field",
        base = base,
        field = field,
    }
end

local function proj_index<T>(base: LValue | Constant<string>, element: lir.Constant<string>): ProjIndex<T>
    return {
        __phantom_type = nil :: any,
        type = "projection",
        kind = "index",
        base = base,
        element = element,
    }
end

local function proj_namecall<T>(base: LValue | Constant<string>, method: Constant<string>, args: {RValue}): ProjNamecall<T>
    return {
        __phantom_type = nil :: any,
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