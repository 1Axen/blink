--!strict
--!native
--!optimize 2
local colorful = require("@vendor/colorful")
local panic = require("@util/panic")
local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

export type Symbols<T> = {
	name: string,
	parent: Symbols<T>?,
	values: { [string]: T },
	children: { [string]: Symbols<T> },
}

local function assert_not_duplicate(symbols: Symbols<any>, name: string)
	if symbols.children[name] ~= nil then
		panic(`Symbols object "{symbols.name}" already has a child "{name}"`)
	end
end

local function create<T>(name: string): Symbols<T>
	return {
		name = name,
		parent = nil :: any,
		values = {},
		children = {},
	}
end

local function child<T>(self: Symbols<T>, name: string): Symbols<T>?
	return self.children[name]
end

local function inner<T>(self: Symbols<T>, name: string): Symbols<T>
	assert_not_duplicate(self, name)

	local symbols = create(name)
	self.children[name] = symbols
	symbols.parent = self

	return symbols
end

--- Adds the `target` symbols object to `self`'s children without setting `target`'s parent.
local function reference<T>(self: Symbols<T>, target: Symbols<T>, name: string)
	assert_not_duplicate(self, name)

	local target_copy: Symbols<T> = table.clone(target)
	target_copy.name = name

	self.children[name] = target_copy
end

local function set<T>(self: Symbols<T>, key: string, value: T)
	self.values[key] = value
end

local function search<T>(self: Symbols<T>, path: { string }): T?
	local index = 1
	local symbols: Symbols<T>? = self
	local segments = path :: { string? }

	while symbols do
		local segment = segments[index]
		if segment == nil then
			break
		end

		local child = symbols.children[segment]
		if child ~= nil then
			index += 1
			symbols = child
			continue
		end

		local value = symbols.values[segment]
		if value ~= nil then
			return value
		end

		symbols = symbols.parent
	end

	return nil
end

local function format<T>(symbols: Symbols<T>): string
	local str_builder = string_builder.create({})

	local parent_symbols
	local symbols_queue = { symbols }

	while symbols_queue do
		local item = table.remove(symbols_queue)
		if item == nil then
			break
		end

		if item.parent ~= parent_symbols then
			parent_symbols = nil
			string_builder.dedent(str_builder)
		end

		local name = item.name
		name = if name == "" then "<ROOT>" else name
		string_builder.append_line(str_builder, colorful.color.yellow(`@{name}`))
		string_builder.indent(str_builder)

		for key in item.values do
			string_builder.append_line(str_builder, `- {key}`)
		end

		-- child symbols
		local inserted_children = false
		for _, child in item.children do
			inserted_children = true
			table.insert(symbols_queue, child)
		end

		if inserted_children then
			parent_symbols = item
			string_builder.indent(str_builder)
		end

		string_builder.dedent(str_builder)
	end

	return string_builder.finalize(str_builder)
end

return table.freeze({
	create = create,
	inner = inner,
	set = set,
	child = child,
	search = search,
	format = format,
	reference = reference,
})
