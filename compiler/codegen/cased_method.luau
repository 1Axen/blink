local options = require("@config/options")

type Casing = index<options.FileOptions, "casing">

local CASING_MAP: { [Casing]: number } = {
	PascalCase = 1,
	camelCase = 2,
	snake_case = 3,
}

local STRINGS = {
	fire = { "Fire", "fire", "fire" },
	fire_all = { "FireAll", "fireAll", "fire_all" },
	fire_list = { "FireList", "fireList", "fire_list" },
	fire_except = { "FireExcept", "fireExcept", "fire_except" },
	invoke = { "Invoke", "invoke", "invoke" },
	on = { "On", "on", "on" },
	iter = { "Iter", "iter", "iter" },
	read = { "Read", "read", "read" },
	write = { "Write", "write", "write" },
	read_from = { "ReadFrom", "readFrom", "read_from" },
	write_to = { "WriteTo", "writeTo", "write_to" },
	step_replication = { "StepReplication", "stepReplication", "step_replication" },
}

export type Method = keyof<typeof(STRINGS)>

local function cased_method(casing: Casing, method: Method): string
	local index = CASING_MAP[casing]
	local casings = STRINGS[method]
	return casings[index] or casings[1]
end

return cased_method
