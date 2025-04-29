--!strict

local lir = require("@lir/types")

type TermIf = lir.TermIf
type TermNone = lir.TermNone
type TermGoto = lir.TermGoto
type TermLoop = lir.TermLoop
type TermCall = lir.TermCall
type TermReturn = lir.TermReturn

type Loop = lir.Loop
type RValue = lir.RValue<any>
type Condition = lir.Condition<boolean>
type BasicBlock = lir.BasicBlock

local function term_if(condition: Condition, truthy: BasicBlock, falsey: BasicBlock, chained: boolean?): TermIf
    return {
        type = "terminator",
        kind = "if",
        cond = condition :: any,
        truthy = truthy,
        falsey = falsey,
        chained = chained
    }
end

local function term_none(): TermNone
    return {
        type = "terminator",
        kind = "none"
    }
end

local function term_goto(destination: BasicBlock): TermGoto
    return {
        type = "terminator",
        kind = "goto",
        destination = destination
    }
end

local function term_loop(loop: Loop, destination: BasicBlock): TermLoop
    return {
        type = "terminator",
        kind = "loop",
        loop = loop,
        destination = destination
    }
end

local function term_call(fn: lir.FnId, args: {RValue}, destination: BasicBlock): TermCall
    return {
        type = "terminator",
        kind = "call",
        fn = fn,
        args = args,
        destination = destination
    }
end

local function term_return(values: {RValue}): TermReturn
    return {
        type = "terminator",
        kind = "return",
        values = values
    }
end

return table.freeze({
    ifbr = term_if,
    none = term_none,
    goto = term_goto,
    loop = term_loop,
    call = term_call,
    rtrn = term_return
})