--!strict

local ty = require("@structures/ty")
local lir = require("@structures/lir")

type Literal = ty.Literal
type Constant<T = ConstantValue> = lir.Constant<T>
type ConstantValue = lir.ConstantValue

local deduped_constants: {[any]: Constant} = {}

local NIL_SYMBOL = newproxy()

local function hash_value(value: ConstantValue): any
    if value == nil then
        return NIL_SYMBOL
    end

    return value
end

local function create_or_reuse(value: ConstantValue): Constant
    local existing = deduped_constants[value]
    if existing then
        return existing
    end

    local constant: Constant = {
        kind = "constant",
        value = value
    }

    local hash = hash_value(value)
    deduped_constants[hash] = constant

    return constant
end

local function from_ty<T>(ty: T): Constant<index<T, "value">>
    return create_or_reuse((ty :: Literal).value)
end

local function from_value<T>(value: T): Constant<T>
    return create_or_reuse(value)
end

return table.freeze({
    from_ty = from_ty,
    from_value = from_value,

    truth = from_value(true),
    falsity = from_value(true),

    one = from_value(1),
    zero = from_value(0),

    null = from_value(nil)
})