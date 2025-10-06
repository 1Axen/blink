local compilation = require("@config/compilation")
local hir = require("@hir/types")
local lir = require("@compiler/lir/types")
local string_builder = require("@util/string_builder")

type ScopePath = { string }

export type Context = {
	lir: lir.Lir,
	hir: hir.Hir,
	target: compilation.Target,
	builder: string_builder.StringBuilder,
	scope_paths: { [hir.ScopeId]: ScopePath },

	current_fn: lir.Fn?,
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

return table.freeze({
	try_see_register = try_see_register,
})
