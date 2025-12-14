local ast = require("@ast")
local typeforge = require("@util/typeforge")

type StringSingletonToType<T> = typeforge.StringSingletonToType<T>

type function MakeOptionsReal(options: type)
	local props = {}
	for key, property in options:properties() do
		local value = assert(property.read)
		local kind = value:readproperty(types.singleton("kind"))
		if kind == nil then
			error(`Expected option "{key}" to have a "kind" field.`)
		end

		local key_type = StringSingletonToType(kind)
		local values = value:readproperty(types.singleton("values"))
		if values then
			assert(values:is("table"), 'Expected "values" field to be an array')

			local indexer = assert(values:indexer())
			key_type = assert(indexer.readresult)
		end

		props[key] = types.unionof(key_type, types.singleton(nil))
	end

	return types.newtable(props)
end

export type Option = {
	kind: index<ast.ExprLiteral, "kind">,
	values: { string | number | boolean }?,
}

local options = {
	typescript = { kind = "boolean" :: "boolean" },
	types_output = { kind = "string" :: "string" },
	client_output = { kind = "string" :: "string" },
	server_output = { kind = "string" :: "string" },

	casing = {
		kind = "string" :: "string",
		values = {
			"PascalCase" :: "PascalCase",
			"camelCase" :: "camelCase",
			"snake_case" :: "snake_case",
		},
		default = "snake_case" :: "snake_case",
	},

	future_library = { kind = "string" :: "string" },
	promise_library = { kind = "string" :: "string" },

	manual_replication = { kind = "boolean" :: "boolean" },
}

export type FileOptions = MakeOptionsReal<typeof(options)>

return table.freeze(options)
