--!strict
--!native
--!optimize 2
local panic = require("@util/panic")

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

--- Sets `child`'s parent to `self`, and adds `child` as a child of `self`
local function adopt<T>(self: Symbols<T>, child: Symbols<T>, name: string)
	assert_not_duplicate(self, name)
	child.parent = self
	self.children[name] = child
end

--- Adds the `target` symbols object to `self`'s children without setting `target`'s parent.
local function reference<T>(self: Symbols<T>, target: Symbols<T>, name: string)
	assert_not_duplicate(self, name)
	self.children[name] = target
end

local function set<T>(self: Symbols<T>, key: string, value: T)
	self.values[key] = value
end

local function search<T>(self: Symbols<T>, path: { string }): T?
	local node: Symbols<T>? = self

	for index = #path, 1, -1 do
		local segment = path[index]
		local child = node.children[segment] :: any
		if child then
			node = child
			continue
		end

		local value = node.values[segment]
		if value ~= nil then
			return value
		end

		node = node.parent :: any

		if node == nil then
			break
		end
	end

	return nil
end

return table.freeze({
	create = create,
	adopt = adopt,
	inner = inner,
	set = set,
	child = child,
	search = search,
	reference = reference,
})
