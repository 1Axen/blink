local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

return function(of: Datatype): Datatype
	local function append(builder: StringBuilder)
		of.append(builder)
		builder:append("[]")
	end

	local function generate(seed: number)
		local size = math.random(0, 8)
		local array = table.create(size)
		for index = 1, size do
			array[index] = of.generate(seed)
		end
		return array
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
