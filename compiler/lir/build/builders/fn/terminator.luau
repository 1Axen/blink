--!strict

local lir = require("@lir/types")

type TermIf = lir.TermIf
type TermNone = lir.TermNone
type TermGoto = lir.TermGoto
type TermLoop = lir.TermLoop
type TermCall = lir.TermCall
type TermWhile = lir.TermWhile
type TermReturn = lir.TermReturn
type TermIfChain = lir.TermIfChain

type Loop = lir.Loop
type LValue = lir.LValue<any>
type RValue = lir.RValue<any>
type Condition = lir.Condition<boolean>
type BasicBlock = lir.BasicBlock

local function term_if_single(condition: Condition, truthy: BasicBlock, falsey: BasicBlock): TermIf
	return {
		type = "terminator",
		kind = "if",
		cond = condition :: any,
		truthy = truthy,
		falsey = falsey,
	}
end

local function term_if_chain(
	condition: Condition,
	truthy: BasicBlock,
	falsey: BasicBlock,
	chain_index: number,
	chain_length: number
): TermIfChain
	return {
		type = "terminator",
		kind = "if_chain",
		cond = condition :: any,
		truthy = truthy,
		falsey = falsey,
		chain_index = chain_index,
		chain_length = chain_length,
	}
end

local function term_none(): TermNone
	return {
		type = "terminator",
		kind = "none",
	}
end

local function term_goto(destination: BasicBlock): TermGoto
	return {
		type = "terminator",
		kind = "goto",
		destination = destination,
	}
end

local function term_loop(loop: Loop, destination: BasicBlock): TermLoop
	return {
		type = "terminator",
		kind = "loop",
		loop = loop,
		destination = destination,
	}
end

local function term_call(fn: lir.FnId, args: { RValue }, rets: { LValue }, destination: BasicBlock): TermCall
	return {
		type = "terminator",
		kind = "call",
		fn = fn,
		args = args,
		rets = rets,
		destination = destination,
	}
end

local function term_while(condition: Condition, truthy: BasicBlock, falsey: BasicBlock): TermWhile
	return {
		type = "terminator",
		kind = "while",
		cond = condition :: any,
		truthy = truthy,
		falsey = falsey,
	}
end

local function term_return(values: { RValue }): TermReturn
	return {
		type = "terminator",
		kind = "return",
		values = values,
	}
end

return table.freeze({
	if_single = term_if_single,
	if_chain = term_if_chain,
	none = term_none,
	goto = term_goto,
	loop = term_loop,
	call = term_call,
	rtrn = term_return,
	while_loop = term_while,
})
