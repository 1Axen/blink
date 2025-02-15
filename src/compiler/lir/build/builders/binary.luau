--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type BinaryAdd = lir.BinaryAdd
type BinarySub = lir.BinarySub
type BinaryMul = lir.BinaryMul
type BinaryDiv = lir.BinaryDiv
type BinaryMod = lir.BinaryMod

local function binary_add(left: RValue, right: RValue): BinaryAdd
    return {
        type = "binary",
        kind = "add",
        left = left,
        right = right
    }
end

local function binary_sub(left: RValue, right: RValue): BinarySub
    return {
        type = "binary",    
        kind = "sub",
        left = left,
        right = right
    }
end

local function binary_mul(left: RValue, right: RValue): BinaryMul
    return {
        type = "binary",
        kind = "mul",
        left = left,
        right = right
    }
end

local function binary_div(left: RValue, right: RValue): BinaryDiv
    return {
        type = "binary",
        kind = "div",
        left = left,
        right = right
    }
end

local function binary_mod(left: RValue, right: RValue): BinaryMod
    return {
        type = "binary",
        kind = "mod",
        left = left,
        right = right
    }
end

return table.freeze({
    add = binary_add,
    sub = binary_sub,
    mul = binary_mul,
    div = binary_div,
    mod = binary_mod
})