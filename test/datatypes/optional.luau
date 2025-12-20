local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

return function(of: Datatype): Datatype
	local function append(builder: StringBuilder)
		of.append(builder)
		builder:append("?")
	end

	local function generate(seed: number)
		return if seed % 2 == 0 then of.generate(seed) else nil
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
