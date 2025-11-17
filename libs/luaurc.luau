local json = require("@util/json")
local path = require("@util/path")
local result = require("@util/result")

type Error<E> = result.Error<E>
type Result<T, E> = result.Result<T, E>

type SerdeError = {
	kind: "SerdeError",
	message: string,
}

type MalformedSchema = {
	kind: "MalformedSchema",
	message: string,
}

--stylua: ignore
export type ParseError = 
	| SerdeError 
	| MalformedSchema

local LINTS = {
	UnknownGlobal = true,
	DeprecatedGlobal = true,
	GlobalUsedAsLocal = true,
	LocalShadow = true,
	SameLineStatement = true,
	MultiLineStatement = true,
	LocalUnused = true,
	FunctionUnused = true,
	ImportUnused = true,
	BuiltinGlobalWrite = true,
	PlaceholderRead = true,
	UnreachableCode = true,
	UnknownType = true,
	ForRange = true,
	UnbalancedAssignment = true,
	ImplicitReturn = true,
	DuplicateLocal = true,
	FormatString = true,
	TableLiteral = true,
	UninitializedLocal = true,
	DuplicateFunction = true,
	DeprecatedApi = true,
	TableOperations = true,
	DuplicateCondition = true,
	MisleadingAndOr = true,
	CommentDirective = true,
	IntegerParsing = true,
	ComparisonPrecedence = true,
	["*"] = true,
}

local CONFIG_NAME = ".luaurc"

local LANGUAGE_MODES = { "nonstrict", "strict", "nocheck" }

type JSONLuaurc = {
	read languageMode: "nocheck" | "nonstrict" | "strict"?,

	read lint: { [keyof<typeof(LINTS)>]: boolean }?,
	read aliases: { [string]: string }?,
	read globals: { string }?,

	read lintErrors: boolean?,
	read typeErrors: boolean?,
}

--- https://github.com/luau-lang/rfcs/blob/master/docs/config-luaurc.md
type Luaurc = {
	read languageMode: "nocheck" | "nonstrict" | "strict"?,

	read lint: { [keyof<typeof(LINTS)>]: boolean }?,
	read aliases: { [string]: path.Path }?,
	read globals: { string }?,

	read lintErrors: boolean,
	read typeErrors: boolean,
}

local function serde_error(message: string): Error<SerdeError>
	return result.err({
		kind = "SerdeError" :: "SerdeError",
		message = message,
	})
end

local function malformed_schema(message: string): Error<MalformedSchema>
	return result.err({
		kind = "MalformedSchema" :: "MalformedSchema",
		message = message,
	})
end

local function is_one_of(value: any, variants: { any }): boolean
	return table.find(variants, value) ~= nil
end

local function validate_schema(schema: JSONLuaurc): Result<nil, MalformedSchema>
	local language_mode = schema.languageMode
	if language_mode and is_one_of(language_mode, LANGUAGE_MODES) == false then
		return malformed_schema(`Unknown language mode, expected one of {table.concat(LANGUAGE_MODES, ", ")}.`)
	end

	local lintErrors = schema.lintErrors
	if lintErrors and typeof(lintErrors) ~= "boolean" then
		return malformed_schema('Expected "lintErrors" to be of type "boolean"')
	end

	local typeErrors = schema.typeErrors
	if typeErrors and typeof(typeErrors) ~= "boolean" then
		return malformed_schema('Expected "typeErrors" to be of type "boolean"')
	end

	local lint = schema.lint
	if lint then
		if typeof(lint) ~= "table" then
			return malformed_schema('Expected "lint" to be of type "table"')
		end

		for key, value in lint :: { [string]: boolean } do
			if LINTS[key] ~= true then
				return malformed_schema(`Unknown lint "{key}"`)
			end
			if typeof(value) ~= "boolean" then
				return malformed_schema(`Expected value of lint "{key}" to be of type "boolean"`)
			end
		end
	end

	local aliases = schema.aliases
	if aliases then
		if typeof(aliases) ~= "table" then
			return malformed_schema('Expected "aliases" to be of type "table"')
		end

		for key, value in aliases do
			if typeof(key) ~= "string" then
				return malformed_schema(`Expected key of alias to be of type "string"`)
			end
			if typeof(value) ~= "string" then
				return malformed_schema(`Expected value of alias "{key}" to be of type "string"`)
			end
		end
	end

	local globals = schema.globals
	if globals then
		if typeof(globals) ~= "table" then
			return malformed_schema('Expected "globals" to be of type "table"')
		end

		local last_index = 0
		for index, value in globals do
			if typeof(index) ~= "number" then
				return malformed_schema('Expected "globals" table to be an array')
			end

			if typeof(value) ~= "string" then
				return malformed_schema('Expected "globals" table to be an array of strings')
			end

			-- check for contigous array
			local distance = (index - last_index)
			if distance ~= 1 then
				return malformed_schema('Expected "globals" array table to be contigous')
			end

			last_index = index
		end
	end

	return result.ok()
end

--- Takes in the json contents of a `.luaurc` file and returns a result of a Luaurc struct
local function from_json(contents: string): result.Result<Luaurc, ParseError>
	-- Phase 1: Decode the file contents
	local serde_success, serde_result = pcall(function()
		return json.decode(contents)
	end)

	if serde_success == false then
		return serde_error(serde_result :: string)
	end

	local schema = serde_result :: JSONLuaurc

	-- Phase 2: Validate the schema
	if typeof(schema) ~= "table" then
		return malformed_schema("Expected schema to be an object")
	end

	local validation_result = validate_schema(schema)
	if validation_result.error then
		return validation_result
	end

	-- Phase 3: Build luaurc struct
	local aliases: { [string]: path.Path }?
	if schema.aliases then
		aliases = {}

		for alias, relative_path in schema.aliases do
			aliases[alias] = path.from_string(relative_path)
		end
	end

	local luaurc: Luaurc = table.freeze({
		languageMode = schema.languageMode,

		lint = schema.lint,
		aliases = aliases,
		globals = schema.globals,

		lintErrors = schema.lintErrors or true,
		typeErrors = schema.typeErrors or false,
	})

	return result.ok(luaurc)
end

--- Serializes the provided luaurc into a JSON formatted string.
local function serialize(self: Luaurc): result.Result<string, SerdeError>
	local serde_success, serde_result = pcall(function()
		return json.encode(self)
	end)

	if serde_success == false then
		return serde_error(serde_result)
	end

	return result.ok(serde_result)
end

return table.freeze({
	from_json = from_json,
	serialize = serialize,

	CONFIG_NAME = CONFIG_NAME,
})
