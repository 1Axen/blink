local json = require("@util/json")
local option = require("@util/option")
local path = require("@util/path")
local result = require("@util/result")

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

type SerdeError = "SerdeError"
type MalformedSchema = "MalformedSchema"

export type CtorError = | SerdeError | MalformedSchema

local function serde_error(): result.Error<SerdeError>
	return result.err("SerdeError" :: SerdeError)
end

local function malformed_schema(): result.Error<MalformedSchema>
	return result.err("MalformedSchema" :: MalformedSchema)
end

local function is_one_of(value: any, variants: { any }): boolean
	return table.find(variants, value) ~= nil
end

local function is_valid_schema(schema: JSONLuaurc): boolean
	local language_mode = schema.languageMode
	if language_mode and is_one_of(language_mode, { "nonstrict", "strict", "nocheck" }) == false then
		return false
	end

	local lintErrors = schema.lintErrors
	if lintErrors and typeof(lintErrors) ~= "boolean" then
		return false
	end

	local typeErrors = schema.typeErrors
	if typeErrors and typeof(typeErrors) ~= "boolean" then
		return false
	end

	local lint = schema.lint

	if lint then
		if typeof(lint) ~= "table" then
			return false
		end

		for key, value in lint :: { [string]: boolean } do
			if LINTS[key] ~= true then
				return false
			end
			if typeof(value) ~= "boolean" then
				return false
			end
		end
	end

	local aliases = schema.aliases
	if aliases then
		if typeof(aliases) ~= "table" then
			return false
		end

		for key, value in aliases do
			if typeof(key) ~= "string" then
				return false
			end
			if typeof(value) ~= "string" then
				return false
			end
		end
	end

	local globals = schema.globals
	if globals then
		if typeof(aliases) ~= "table" then
			return false
		end

		local last_index = 0
		for index, value in aliases do
			if typeof(index) ~= "number" then
				return false
			end

			if typeof(value) ~= "string" then
				return false
			end

			-- check for contigous array
			local distance = (index - last_index)
			if distance ~= 1 then
				return false
			end

			last_index = index
		end
	end

	return true
end

--- Takes in the json contents of a `.luaurc` file and returns a result of a Luaurc struct
local function from_json(contents: string): result.Result<Luaurc, CtorError>
	-- Phase 1: Decode the file contents
	local serde_success, schema = pcall(function()
		return json.decode(contents) :: JSONLuaurc
	end)

	if serde_success == false then
		return serde_error()
	end

	-- Phase 2: Validate the schema
	if typeof(schema) ~= "table" then
		return malformed_schema()
	end

	if is_valid_schema(schema) == false then
		return malformed_schema()
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

--- Returns the underlying aliases map.
local function aliases(self: Luaurc): option.Option<index<Luaurc, "aliases">>
	local aliases = self.aliases
	if aliases == nil then
		return option.none()
	end

	return option.some(aliases)
end

--- Serializes the provided luaurc into a JSON formatted string.
local function serialize(self: Luaurc): result.Result<string, SerdeError>
	local serde_success, json_string = pcall(function()
		return json.encode(self)
	end)

	if serde_success == false then
		return serde_error()
	end

	return result.ok(json_string)
end

return table.freeze({
	from_json = from_json,
	aliases = aliases,
	serialize = serialize,

	CONFIG_NAME = CONFIG_NAME,
})
