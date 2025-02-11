--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue

local function condition(kind: index<lir.Condition, "kind">, left: RValue, right: RValue): lir.Condition
    if kind == "always" then
        return { kind = "always" }
    end
    
    return {
        kind = kind,
        left = left,
        right = right
    }
end

return table.freeze({
    equals = function(left: RValue, right: RValue)
        return condition("equals", left, right)
    end,
    not_equals = function(left: RValue, right: RValue)
        return condition("not_equals", left, right)
    end,
    less_than = function(left: RValue, right: RValue)
        return condition("less_than", left, right)
    end,
    less_than_or = function(left: RValue, right: RValue)
        return condition("less_than_or", left, right)
    end,
    greater_than = function(left: RValue, right: RValue)
        return condition("greater_than", left, right)
    end,
    greater_than_or = function(left: RValue, right: RValue)
        return condition("greater_than_or", left, right)
    end,
    always = function(): lir.Condition
        return {kind = "always"}
    end
})