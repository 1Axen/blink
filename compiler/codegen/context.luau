local hir = require("@hir")
local lir = require("@compiler/lir/types")
local string_builder = require("@util/string_builder")

type BasicBlock = lir.BasicBlock

export type Context = {
	lir: lir.Lir,
	hir: hir.Hir,
	builder: string_builder.StringBuilder,

	current_fn: lir.FnBody?,
	current_block: BasicBlock?,
	--- map of scopes at which an if chain is present
	if_chains: { [number]: true },
	--- FILO queue of blocks to process
	block_queue: { BasicBlock },
	--- filter to prevent duplicate insertions into the queue
	block_queue_filter: { [number]: true },
	seen_registers: { [number]: true },
}

--- Attempts to mark a register as seen, returns true if this is the first time this register was seen.
--- *For LValues that aren't registers this always returns false.*
local function try_see_register<T>(ctx: Context, lvalue: lir.LValue<T>): boolean
	if lvalue.type ~= "id" or lvalue.kind ~= "register" then
		return false
	end

	local index = lvalue.index
	local seen_registers = ctx.seen_registers
	if seen_registers[index] then
		return false
	end

	seen_registers[index] = true
	return true
end

local function pop_block(ctx: Context): BasicBlock?
	local block = table.remove(ctx.block_queue, #ctx.block_queue)
	if block == nil then
		return nil
	end

	ctx.block_queue_filter[block.index] = nil
	return block
end

local function push_block(ctx: Context, block: BasicBlock)
	local index = block.index
	local filter = ctx.block_queue_filter
	if filter[index] then
		return
	end

	filter[index] = true
	table.insert(ctx.block_queue, block)
end

return table.freeze({
	pop_block = pop_block,
	push_block = push_block,
	try_see_register = try_see_register,
})
