--!strict

local lir = require("@compiler/structures/lir")

type LValue = lir.LValue
type LRValue = lir.LRValue

type Numeric = lir.LoopNumeric
type Generic = lir.LoopGeneric

type Register = lir.RegisterId

local function loop_numeric(index: Register, iterations: LRValue): Numeric
    return {
        kind = "numeric",
        index = index,
        iterations = iterations
    }
end

local function loop_generic(index: Register?, value: Register, target: LValue): Generic
    return {
        kind = "generic",
        index = index,
        value = value,
        target = target
    }
end

return table.freeze({
    numeric = loop_numeric,
    generic = loop_generic
})
