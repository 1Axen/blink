--!strict
--!native
--!optimize 2

local range = require("@util/range")

type Range = range.Range
type Generic = {
    
}

export type Primitive = {
    range: range.Range?,
    generics: number?
}

local F64 = 2^53
local F32 = 2^24

local function size_to_range(bits: number): Range
    --> lose one bit for the sign
    local max = (2 ^ (bits - 1))
    local min = -max

    return range.create(min, max - 1)
end

local function usize_to_range(bits: number): Range
    return range.create(0, (2 ^ bits) - 1)
end

local primitives: {[string]: Primitive} = {
    --> Numerals
    u8 = { range = usize_to_range(8) },
    u16 = { range = usize_to_range(16) },
    u32 = { range = usize_to_range(32) },
    u48 = { range = usize_to_range(48) },

    i8 = { range = size_to_range(8) },
    i16 = { range = size_to_range(16) },
    i32 = { range = size_to_range(32) },
    i48 = { range = size_to_range(48) },

    f32 = { range = range.create(-F32, F32) },
    f64 = { range = range.create(-F64, F64) },

    --> Luau primitives
    string = { range = usize_to_range(32) },
    -- https://github.com/luau-lang/luau/blob/d0222bb55465e05f03d4e4a84f7eb53d49c0c3f4/VM/src/lbuffer.h#L7
    buffer = { range = usize_to_range(30) },
    vector = {
        range = range.create(-F32, F32),
        generics = 3
    },
    boolean = { },

    --> ROBLOX types
    CFrame = { 
        generics = 2
    },
    
    Color3 = { },
    BrickColor = { },
    Instance = { generics = 1 },
    
    DateTime = { },
    DateTimeMillis = { },

    --> Blink types
    unknown = { }
}

return table.freeze(primitives)