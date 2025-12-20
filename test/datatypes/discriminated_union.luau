local string_builder = require("@util/string_builder")
local tableext = require("@std/tableext")
local types = require("./types")

type Datatype = types.Datatype
type StringBuilder = string_builder.StringBuilder

local function key_to_string(key: any): string
	if type(key) == "string" then
		return `"{key}"`
	end

	return tostring(key)
end

return function(tag: string, variants: { [any]: Datatype }): Datatype
	local keys = tableext.keys(variants)
	local function append(builder: StringBuilder)
		builder:append('union "')
		builder:append(tag)
		builder:append('" {')

		for key, variant in variants do
			builder:append(key_to_string(key))
			builder:append(" { value: ")
			variant.append(builder)
			builder:append(" },")
		end

		builder:append("}")
	end

	local function generate(seed: number)
		local key = keys[math.random(1, #keys)]
		local variant = variants[key]

		return {
			[tag] = key,
			value = variant.generate(seed),
		}
	end

	return table.freeze({
		append = append,
		generate = generate,
	})
end
