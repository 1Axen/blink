--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

local function ctrl_advance(bytes: RValue): Advance
    return {
        type = "control",
        kind = "advance",
        bytes = bytes
    }
end

local function ctrl_allocate(bytes: RValue): Allocate
    return {
        type = "control",
        kind = "allocate",
        bytes = bytes
    }
end

return table.freeze({
    advance = ctrl_advance,
    allocate = ctrl_allocate
})