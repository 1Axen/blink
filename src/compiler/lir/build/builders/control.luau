--!strict

local lir = require("@structures/lir")

type RValue = lir.RValue
type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

local function ctrl_advance(bytes: RValue): Advance
    return {
        kind = "advance",
        bytes = bytes
    }
end

local function ctrl_allocate(bytes: RValue): Allocate
    return {
        kind = "allocate",
        bytes = bytes
    }
end

return table.freeze({
    advance = ctrl_advance,
    allocate = ctrl_allocate
})