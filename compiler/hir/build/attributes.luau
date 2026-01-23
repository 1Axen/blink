local ast = require("@ast")
local attributes = require("@config/attributes")
local compilation = require("@config/compilation")
local report = require("@compiler/report")
local weak_exhaustive_match = require("@util/weak_exhaustive_match")

type Attributes = attributes.Attributes
type AttributeNode = ast.Attribute
type AttributeNodes = { AttributeNode }

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

local function expect_n_parameters(attribute: AttributeNode, expected: number)
	local got = #attribute.args
	if got > expected then
		report.extra_attribute_parameters(attribute, expected)
	elseif got < expected then
		report.few_attribute_parameters(attribute, expected)
	end
end

local function attr_target(attribute: AttributeNode): compilation.Target
	expect_n_parameters(attribute, 1)

	local target = attribute.args[1]
	if target.kind ~= "string" then
		-- LUAU
		return report.expect_node(target :: any, "string", target.kind)
	end

	local value = target.value
	if TARGETS[value] ~= true then
		-- LUAU
		return report.expect_node_one_of(target :: any, set_to_array(TARGETS), value)
	end

	return value :: compilation.Target
end

local function attr_profile(attribute: AttributeNode): compilation.Profile
	-- validate count
	expect_n_parameters(attribute, 1)

	-- validate kind
	local profile = attribute.args[1]
	if profile.kind ~= "string" then
		-- LUAU
		return report.expect_node(profile :: any, "string", profile.kind)
	end

	local value = profile.value :: string
	if PROFILES[value] ~= true then
		-- LUAU
		return report.expect_node_one_of(profile :: any, set_to_array(PROFILES), value)
	end

	return value :: compilation.Profile
end

--- Used for attributes that don't take parameters
local function attr_any(attribute: AttributeNode): true
	-- validate count
	expect_n_parameters(attribute, 0)

	return true
end

local function from_nodes(nodes: AttributeNodes): Attributes
	-- Fix `cannot add indexer` error
	local attributes: Attributes & { [any]: any } = {}

	for _, attribute in nodes do
		local name = attribute.name.value :: keyof<Attributes>
		local value: any?

		if name == "profile" then
			value = attr_profile(attribute)
		elseif name == "target" then
			value = attr_target(attribute)
		elseif name == "bitpack" then
			value = attr_any(attribute)
		elseif name == "stable" then
			value = attr_any(attribute)
		elseif name == "export" then
			value = attr_any(attribute)
		else
			weak_exhaustive_match(name)
			return report.invalid_attribute(attribute)
		end

		attributes[name] = value
	end

	return attributes
end

return table.freeze({
	from_nodes = from_nodes,
})
