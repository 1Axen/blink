local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

return function(indexer: Datatype, value: Datatype): Datatype
	local function append(builder: StringBuilder)
		builder:append("map {[")
		indexer.append(builder)
		builder:append("]: ")
		value.append(builder)
		builder:append("}")
	end

	local function generate(seed: number)
		local map = {}
		for _ = 1, math.random(0, 8) do
			map[indexer.generate(seed)] = value.generate(seed)
		end
		return map
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
