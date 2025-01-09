--!strict

local lir = require("@compiler/structures/lir")

type Value = lir.Value

local function condition(kind: index<lir.Condition, "kind">, left: Value, right: Value): lir.Condition
    return {
        kind = kind,
        left = left,
        right = right
    }
end

return table.freeze({
    equals = function(left: Value, right: Value)
        return condition("Equals", left, right)
    end,
    not_equals = function(left: Value, right: Value)
        return condition("NotEquals", left, right)
    end,
    less_than = function(left: Value, right: Value)
        return condition("LessThan", left, right)
    end,
    less_than_or = function(left: Value, right: Value)
        return condition("LessThanOr", left, right)
    end,
    greater_than = function(left: Value, right: Value)
        return condition("GreaterThan", left, right)
    end,
    greater_than_or = function(left: Value, right: Value)
        return condition("GreaterThanOr", left, right)
    end,
})