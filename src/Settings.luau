type NumberRange = {Min: number, Max: number}
local NumberRange = {
    new = function(Min: number, Max: number?): NumberRange
        return {
            Min = Min,
            Max = Max or Min
        }
    end
}

export type Case = "Camel" | "Snake" | "Pascal"
export type Cases = {
    Fire: string,
    FireAll: string,
    FireList: string,
    FireExcept: string,
    On: string,
    Invoke: string,
}

export type Primitive = {
    Bounds: NumberRange?,
    AllowsRange: boolean,
    AllowsOptional: boolean,
}

local Indexes = {
    Pascal = 1,
    Camel = 2,
    Snake = 3
}

local Cases = {
    On = {"On", "on", "on"},
    Invoke = {"Invoke", "invoke", "invoke"},
    Fire = {"Fire", "fire", "fire"},
    FireAll = {"FireAll", "fireAll", "fire_all"},
    FireList = {"FireList", "fireList", "fire_list"},
    FireExcept = {"FireExcept", "fireExcept", "fire_except"},
}

local Primitives: {[string]: Primitive} = {
    u8 = {
        Bounds = NumberRange.new(0, 255),
        AllowsRange = true,
        AllowsOptional = true,
    },
    u16 = {
        Bounds = NumberRange.new(0, 65535),
        AllowsRange = true,
        AllowsOptional = true,
    },
    u32 = {
        Bounds = NumberRange.new(0, 4294967295),
        AllowsRange = true,
        AllowsOptional = true,
    },
    i8 = {
        Bounds = NumberRange.new(-128, 127),
        AllowsRange = true,
        AllowsOptional = true,
    },
    i16 = {
        Bounds = NumberRange.new(-32768, 32767),
        AllowsRange = true,
        AllowsOptional = true,
    },
    i32 = {
        Bounds = NumberRange.new(-2147483648, 2147483647),
        AllowsRange = true,
        AllowsOptional = true,
    },
    f16 = {
        Bounds = NumberRange.new(-65504, 65504),
        AllowsRange = true,
        AllowsOptional = true,
    },
    f32 = {
        Bounds = NumberRange.new(-16777216, 16777216),
        AllowsRange = true,
        AllowsOptional = true,
    },
    f64 = {
        Bounds = NumberRange.new(-2^53, 2^53),
        AllowsRange = true,
        AllowsOptional = true,
    },
    boolean = {
        AllowsRange = false,
        AllowsOptional = true,
    },
    string = {
        Bounds = NumberRange.new(0, 65535),
        AllowsRange = true,
        AllowsOptional = true,
    },
    vector = {
        AllowsRange = true,
        AllowsOptional = true,
    },
    buffer = {
        Bounds = NumberRange.new(0, 65535),
        AllowsRange = true,
        AllowsOptional = true,
    },
    Color3 = {
        AllowsRange = false,
        AllowsOptional = true,
    },
    CFrame = {
        AllowsRange = false,
        AllowsOptional = true,
    },
    Instance = {
        AllowsRange = false,
        AllowsOptional = true,
    },
    unknown = {
        AllowsRange = false,
        AllowsOptional = false,
    }
}

return {
    Keywords = {
        map = true,
        type = true,
        enum = true,
        struct = true,

        event = true,
        ["function"] = true,

        scope = true,
        option = true,
    },

    Primtives = Primitives,
    GetCasing = function(Case: Case): Cases
        local Index = Indexes[Case]
        if not Index then
            error(`Unknown casing "{Case}", expectd one of "Pascal" or "Camel" or "Snake"`)
        end

        local Casing: any = {}
        for Key, Options in Cases do
            Casing[Key] = Options[Index]
        end
        return Casing
    end
}