local compilation = require("@config/compilation")
local hir = require("@hir/types")
local lir = require("@compiler/lir/types")
local string_builder = require("@util/string_builder")

export type Context = {
	lir: lir.Lir,
	hir: hir.Hir,
	target: compilation.Target,
	builder: string_builder.StringBuilder,
	seen_registers: { [number]: true },
}

return nil
