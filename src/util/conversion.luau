local ty = require("@compiler/structures/ty")
local panic = require("@util/panic")

local U8 = (2 ^ 8) - 1
local U16 = (2 ^ 16) - 1
local U24 = (2 ^ 24) - 1
local U32 = (2 ^ 32) - 1
local U48 = (2 ^ 48) - 1

--- Converts a number to the smallest possible uint numeral size, such that it can be encoded as it.
local function to_min_size(number: number): ty.NumSize
    if number <= U8 then
        return "8"
    elseif number <= U16 then
        return "16"
    elseif number <= U24 then
        return "24"
    elseif number <= U32 then
        return "32"
    elseif number <= U48 then
        return "48"
    end

    return panic(`Cannot convert {number} to numeral size (larger than a u48)`)
end

--- Converts a number to the smallest possible uint byte size, such that it can be encoded as it.
local function to_min_byte_size(number: number): number
    if number <= U8 then
        return 1
    elseif number <= U16 then
        return 2
    elseif number <= U24 then
        return 3
    elseif number <= U32 then
        return 4
    elseif number <= U48 then
        return 5
    end

    return panic(`Cannot convert {number} to byte size (larger than a u48)`)
end

--- Converts a number to the smallest possible unsigned numeral, such that it can be encoded as it.
local function to_min_numeral(number: number): ty.Numeral
    local size = to_min_size(number)
    return ty.numeral(size, "u")
end

return table.freeze({
    to_min_size = to_min_size,
    to_min_numeral = to_min_numeral,
    to_min_byte_size = to_min_byte_size,
})