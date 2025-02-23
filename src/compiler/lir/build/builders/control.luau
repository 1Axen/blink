--!strict

local lir = require("@structures/lir")

type RValue<T> = lir.RValue<T>
type Advance = lir.CtrlAdvance<number>
type Allocate = lir.CtrlAllocate<number>

local function ctrl_advance(bytes: RValue<number>): Advance
    return {
        __phantom_type = nil :: any,
        
        type = "control",
        kind = "advance",
        bytes = bytes :: any
    }
end

local function ctrl_allocate(bytes: RValue<number>): Allocate
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