--!strict

local lir = require("@structures/lir")

type RValue<T = any> = lir.RValue<T>
type Numeric = lir.LoopNumeric
type Generic = lir.LoopGeneric
type Register<T = any> = lir.RegisterId<T>

local function loop_numeric(index: Register<number>, iterations: RValue<number>): Numeric
    return {
        type = "loop",
        kind = "numeric",
        index = index,
        iterations = iterations
    }
end

local function loop_generic(index: Register<any>, value: Register<any>, target: index<Generic, "target">): Generic
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
