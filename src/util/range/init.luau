--!strict
--!native
--!optimize 2

export type Range = {
    read min: number,
    read max: number
}

local function create(min: number, max: number): Range
    return table.freeze({
        min = min,
        max = max
    })
end

--- Returns a range bounded to the minimum and maximum signed value representable in `bits` bits
local function create_from_size(bits: number): Range
    --> lose one bit for the sign
    local max = (2 ^ (bits - 1))
    local min = -max

    return create(min, max - 1)
end

--- Returns a range bounded to the minimum and maximum unsigned value representable in `bits` bits
local function create_from_usize(bits: number): Range
    return create(0, (2 ^ bits) - 1)
end

return table.freeze({
    create = create,
    from_size = create_from_size,
    from_usize = create_from_usize
})