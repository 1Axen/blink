--!strict

local lir = require("@compiler/structures/lir")

type LRValue = lir.LRValue
type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

local function ctrl_advance(bytes: LRValue): Advance
    return {
        kind = "advance",
        bytes = bytes
    }
end

local function ctrl_allocate(bytes: LRValue): Allocate
    return {
        kind = "allocate",
        bytes = bytes
    }
end

return table.freeze({
    advance = ctrl_advance,
    allocate = ctrl_allocate
})