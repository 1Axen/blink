--!strict

local types = require("@lir/types")

type TermIf = types.TermIf
type TermNone = types.TermNone
type TermGoto = types.TermGoto
type TermLoop = types.TermLoop
type TermCall = types.TermCall
type TermWhile = types.TermWhile
type TermReturn = types.TermReturn
type TermIfChain = types.TermIfChain

type Loop = types.Loop
type Readable = types.Readable<any>
type Writeable = types.Writeable<any>
type Condition = types.Condition<boolean>
type BasicBlock = types.BasicBlock

type RValue = types.RValue<any>
type LValue = types.LValue<any>

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

local function term_call(fn: types.FnId, args: { Readable }, rets: { Writeable }, destination: BasicBlock): TermCall
	return {
		type = "terminator",
		kind = "call",
		fn = fn,
		args = args :: { RValue },
		rets = rets :: { LValue },
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

local function term_return(values: { Readable }): TermReturn
	return {
		type = "terminator",
		kind = "return",
		values = values :: { RValue },
	}
end

local function term_continue(): types.TermContinue
	return {
		type = "terminator",
		kind = "continue",
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
	ccontinue = term_continue,
})
