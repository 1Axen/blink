local enum_item = {}
enum_item.__index = enum_item

type EnumItemMock = setmetatable<{
	read Name: string,
	read Value: number,
	read EnumType: EnumMock,
}, typeof(enum_item)>

function enum_item.__eq(self: EnumItemMock, other: EnumItemMock)
	return (self.EnumType == other.EnumType) and (self.Value == other.Value)
end

function enum_item.__tostring(self: EnumItemMock)
	return `Enum.{self.EnumType}.{self.Name}`
end

const function create_enum_item(name: string, value: number, enum: EnumMock): EnumItemMock
	return setmetatable({
		Name = name,
		Value = value,
		EnumType = enum,
	}, enum_item)
end

local enum = {}
enum.__index = enum

type EnumMock<K = any> = setmetatable<{
	read __name: string,
	read __items: { EnumItemMock },
	read [K]: EnumItemMock,
}, typeof(enum)>

function enum.FromValue(self: EnumMock, value: number): EnumItemMock?
	const index = (value + 1)
	return self.__items[index]
end

function enum.GetEnumItems(self: EnumMock)
	return table.clone(self.__items)
end

function enum.__eq(self: EnumMock, other: EnumMock)
	return self.__name == other.__name
end

function enum.__tostring(self: EnumMock)
	return self.__name
end

const function create_enum<T>(name: string, items: { read T | "" }): EnumMock<T>
	const enum_items = table.create<<EnumItemMock>>(#items)
	const self = setmetatable({
		__name = name,
		__items = enum_items,
	}, enum)

	for index, item_name in items do
		const value = (index - 1)
		const enum_item = create_enum_item(item_name, value, self)
		self[item_name] = enum_item
		enum_items[index] = enum_item
	end

	return self
end

const ENUMS = table.freeze({
	Axis = create_enum("Axis", { "X", "Y", "Z" }),
	AlphaMode = create_enum("AlphaMode", { "Overlay", "Transparency", "TintMask", "Opaque" }),
})

return table.freeze({
	ENUMS = ENUMS,
	ENUM_METATABLE = enum,
	ENUM_ITEM_METATABLE = enum_item,
})
