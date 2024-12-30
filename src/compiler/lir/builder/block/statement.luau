--!strict

local lir = require("@compiler/structures/lir")

type Assign = lir.StatAssign

type Value = lir.Value
type Register = lir.RegisterId

local function stat_assign(into: Register, value: Value?): Assign
    return {
        kind = "assign",
        into = into,
        value = value
    }
end

return table.freeze({
    assign = stat_assign
})