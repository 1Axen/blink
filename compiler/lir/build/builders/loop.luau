--!strict

local types = require("@lir/types")

type RValue = types.RValue<any>
type Numeric = types.LoopNumeric
type Generic = types.LoopGeneric
type Readable<T = any> = types.Readable<T>
type Register<T = any> = types.RegisterId<T>

local function loop_numeric(index: Register<number>, iterations: Readable<number>): Numeric
	return {
		type = "loop",
		kind = "numeric",
		index = index,
		iterations = iterations :: RValue,
	}
end

local function loop_generic(index: Register<any>, value: Register<any>, target: index<Generic, "target">): Generic
	return {
		type = "loop",
		kind = "generic",
		index = index,
		value = value,
		target = target,
	}
end

return table.freeze({
	numeric = loop_numeric,
	generic = loop_generic,
})
