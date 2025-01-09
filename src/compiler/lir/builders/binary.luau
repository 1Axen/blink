--!strict

local lir = require("@compiler/structures/lir")

type LRValue = lir.LRValue
type BinaryAdd = lir.BinaryAdd
type BinaryMul = lir.BinaryMul

local function binary_add(left: LRValue, right: LRValue): BinaryAdd
    return {
        kind = "add",
        left = left,
        right = right
    }
end

local function binary_mul(left: LRValue, right: LRValue): BinaryMul
    return {
        kind = "mul",
        left = left,
        right = right
    }
end

return table.freeze({
    add = binary_add,
    mul = binary_mul
})