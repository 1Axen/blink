local string_builder = require("@util/string_builder")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function to_field_name(index: number): string
	return `field_{index}`
end

return function(fields: { Datatype }): Datatype
	local function append(builder: StringBuilder)
		builder:append("struct { ")

		for index, field in fields do
			builder:append_indent()
			builder:append(to_field_name(index))
			builder:append(": ")
			field.append(builder)
			builder:append(",")
		end
		builder:append(" }")
	end

	local function generate()
		local struct = {}
		for index, field in fields do
			local name = to_field_name(index)
			struct[name] = field.generate()
		end

		return struct
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
