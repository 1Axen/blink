--!strict

local ty = require("@compiler/structures/ty")
local lir = require("@compiler/structures/lir")

type Literal = ty.Literal
type Constant = lir.Constant
type ConstantValue = lir.ConstantValue

local deduped_constants: {[ConstantValue]: Constant} = {}

local function create_or_reuse(value: ConstantValue): Constant
    local existing = deduped_constants[value]
    if existing then
        return existing
    end

    local constant: Constant = {
        kind = "constant",
        value = value
    }

    deduped_constants[value] = constant
    return constant
end

local function from_ty(ty: Literal): Constant
    return create_or_reuse(ty.value)
end

local function from_value(value: ConstantValue): Constant
    return create_or_reuse(value)
end

return table.freeze({
    from_ty = from_ty,
    from_value = from_value
})