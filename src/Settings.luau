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
    StepReplication: string,
    Next: string,
    Iter: string,
    Read: string,
    Write: string,
}

export type Primitive = {
    Bounds: NumberRange?,
    Component: boolean,
    AllowsRange: boolean,
    AllowsOptional: boolean,
    AllowedComponents: number,
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
    StepReplication = {"StepReplication", "stepReplication", "step_replication"},
    Next = {"Next", "next", "next"},
    Iter = {"Iter", "iter", "iter"},
    Read = {"Read", "read", "read"},
    Write = {"Write", "write", "write"},
}

local Primitives: {[string]: Primitive} = {
    u8 = {
        Bounds = NumberRange.new(0, 255),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    u16 = {
        Bounds = NumberRange.new(0, 65535),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    u32 = {
        Bounds = NumberRange.new(0, 4294967295),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    i8 = {
        Bounds = NumberRange.new(-128, 127),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    i16 = {
        Bounds = NumberRange.new(-32768, 32767),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    i32 = {
        Bounds = NumberRange.new(-2147483648, 2147483647),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    f16 = {
        Bounds = NumberRange.new(-65504, 65504),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    f32 = {
        Bounds = NumberRange.new(-16777216, 16777216),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    f64 = {
        Bounds = NumberRange.new(-2^53, 2^53),
        Component = true,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    boolean = {
        Component = false,
        AllowsRange = false,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    string = {
        Bounds = NumberRange.new(0, 65535),
        Component = false,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    vector = {
        Component = false,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 1
    },
    buffer = {
        Bounds = NumberRange.new(0, 65535),
        Component = false,
        AllowsRange = true,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    Color3 = {
        Component = false,
        AllowsRange = false,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    CFrame = {
        Component = false,
        AllowsRange = false,
        AllowsOptional = true,
        AllowedComponents = 2
    },
    Instance = {
        Component = false,
        AllowsRange = false,
        AllowsOptional = true,
        AllowedComponents = 0
    },
    unknown = {
        Component = false,
        AllowsRange = false,
        AllowsOptional = false,
        AllowedComponents = 0
    }
}

return {
    Keywords = {
        map = true,
        set = true,
        type = true,
        enum = true,
        struct = true,

        event = true,
        ["function"] = true,

        scope = true,
        option = true,

        export = true,
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