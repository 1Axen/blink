--!strict

local lir = require("@compiler/structures/lir")

type TermIf = lir.TermIf
type TermNone = lir.TermNone
type TermGoto = lir.TermGoto
type TermLoop = lir.TermLoop
type TermCall = lir.TermCall
type TermReturn = lir.TermReturn

type Loop = lir.Loop
type Value = lir.Value
type Condition = lir.Condition
type BasicBlock = lir.BasicBlock

local function term_if(condition: Condition, truthy: BasicBlock, falsey: BasicBlock): TermIf
    return {
        kind = "if",
        cond = condition,
        truthy = truthy,
        falsey = falsey
    }
end

local function term_none(): TermNone
    return {
        kind = "none"
    }
end

local function term_goto(destination: BasicBlock): TermGoto
    return {
        kind = "goto",
        destination = destination
    }
end

local function term_loop(loop: Loop, destination: BasicBlock): TermLoop
    return {
        kind = "loop",
        loop = loop,
        destination = entry
    }
end

local function term_call(fn: lir.Fn, args: {Value}, destination: BasicBlock): TermCall
    return {
        kind = "call",
        fn = fn,
        args = args,
        destination = destination
    }
end

local function term_return(values: {Value}): TermReturn
    return {
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