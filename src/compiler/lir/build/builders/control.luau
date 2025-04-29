--!strict

local lir = require("@lir/types")

type RValue<T> = lir.RValue<T>

local function ctrl_advance(bytes: RValue<number>): lir.CtrlAdvance<number>
    return {
        __phantom_type = nil :: any,
        
        type = "control",
        kind = "advance",
        bytes = bytes :: any
    }
end

local function ctrl_allocate(bytes: RValue<number>): lir.CtrlAllocate<number>
    return {
        __phantom_type = nil :: any,

        type = "control",
        kind = "allocate",
        bytes = bytes :: any
    }
end

return table.freeze({
    advance = ctrl_advance,
    allocate = ctrl_allocate
})