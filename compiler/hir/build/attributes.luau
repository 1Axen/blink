local ast = require("@ast/types")

local attributes = require("@config/attributes")
local compilation = require("@config/compilation")
local report = require("@hir/report")

local exhaustive_match = require("@util/exhaustive_match")

type Attribute = ast.Attribute
type Attributes = { Attribute }

type TypeAttributes = attributes.TypeAttributes
type SharedAttributes = attributes.SharedAttributes

local TARGETS: { [string]: true } = compilation.TARGETS :: any
local PROFILES: { [string]: true } = compilation.PROFILES :: any

local function set_to_array<T>(set: { [T]: true }, sort_comp: ((a: T, b: T) -> boolean)?): { T }
	local array = {}

	for key in set do
		table.insert(array, key)
	end

	if sort_comp then
		table.sort(array, sort_comp)
	end

	return array
end

local function expect_n_parameters(attribute: Attribute, expected: number)
	local got = #attribute.args
	if got > expected then
		report.extra_attribute_parameters(attribute, expected)
	elseif got < expected then
		report.few_attribute_parameters(attribute, expected)
	end
end

local function attr_target(attribute: Attribute): compilation.Target
	expect_n_parameters(attribute, 1)

	local target = attribute.args[1]
	if target.kind ~= "string" then
		-- LUAU
		return report.expect(target :: any, "string", target.kind)
	end

	local value = target.value
	if TARGETS[value] ~= true then
		-- LUAU
		return report.expect_one_of(target :: any, set_to_array(TARGETS), value)
	end

	return value :: compilation.Target
end

local function attr_profile(attribute: Attribute): compilation.Profile
	-- validate count
	expect_n_parameters(attribute, 1)

	-- validate kind
	local profile = attribute.args[1]
	if profile.kind ~= "string" then
		-- LUAU
		return report.expect(profile :: any, "string", profile.kind)
	end

	local value = profile.value :: string
	if PROFILES[value] ~= true then
		-- LUAU
		return report.expect_one_of(profile :: any, set_to_array(PROFILES), value)
	end

	return value :: compilation.Profile
end

--- Used for attributes that don't take parameters
local function attr_any(attribute: Attribute): true
	-- validate count
	expect_n_parameters(attribute, 0)

	return true
end

local function shared_attributes(ast_attributes: Attributes): SharedAttributes
	-- Fix `cannot add indexer` error
	local attributes: SharedAttributes & { [any]: any } = {}

	for _, attribute in ast_attributes do
		local name = attribute.name.value :: keyof<SharedAttributes>
		local value: any?

		if name == "profile" then
			value = attr_profile(attribute)
		elseif name == "target" then
			value = attr_target(attribute)
		else
			exhaustive_match.type_only(name)
			return report.invalid_attribute(attribute)
		end

		attributes[name] = value
	end

	return attributes
end

local function type_attributes(ast_attributes: Attributes): TypeAttributes
	local attributes = {} :: TypeAttributes

	for _, attribute in ast_attributes do
		local name: keyof<TypeAttributes> = attribute.name.value :: any
		local value: any?

		if name == "stub" then
			value = attr_any(attribute)
		elseif name == "stable" then
			value = attr_any(attribute)
		elseif name == "bitpack" then
			value = attr_any(attribute)
		elseif name == "profile" then
			value = attr_profile(attribute)
		elseif name == "target" then
			value = attr_target(attribute)
		else
			exhaustive_match.type_only(name)
			return report.invalid_attribute(attribute)
		end

		attributes[name] = value
	end

	return attributes
end

return table.freeze({
	type = type_attributes,
	shared = shared_attributes,
})
