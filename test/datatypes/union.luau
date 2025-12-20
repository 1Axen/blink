local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

return function(components: { Datatype }): Datatype
	local function append(builder: StringBuilder)
		for index, component in components do
			if index > 1 then
				builder:append(" | ")
			end

			component.append(builder)
		end
	end

	local function generate(seed: number)
		local component = components[math.random(1, #components)]
		return component.generate(seed)
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
