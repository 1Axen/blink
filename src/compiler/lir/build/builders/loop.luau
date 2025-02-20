--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type Numeric = lir.LoopNumeric
type Generic = lir.LoopGeneric
type Register = lir.RegisterId

local function loop_numeric(index: Register, iterations: RValue): Numeric
    return {
        type = "loop",
        kind = "numeric",
        index = index,
        iterations = iterations
    }
end

local function loop_generic(index: Register, value: Register, target: index<Generic, "target">): Generic
    return {
        type = "loop",
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
