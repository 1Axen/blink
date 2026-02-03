export type function StringSingletonToType(singleton: type)
	if singleton:is("singleton") == false then
		error(`Expected a singleton got, "{singleton.tag}" instead`)
	end

	local value = singleton:value()
	if type(value) ~= "string" then
		error(`Expected a string singleton got, "{type(value)}" singleton instead`)
	end

	if value == "string" then
		return types.string
	elseif value == "boolean" then
		return types.boolean
	elseif value == "number" then
		return types.number
	end

	return types.unknown
end

export type function StringUnionToStruct(union: type, value: type?)
	value = value or types.any

	local props = {}
	for index, component in union:components() do
		if not (component:is("singleton") and type(component:value()) == "string") then
			local tag = component.tag
			error(`Expected a union of string singletons, but got "{tag}" at index {index} instead`)
		end

		props[component] = value
	end

	return types.newtable(props)
end

export type function Writeable(t: type): type
	local function make_writeable(tbl: type)
		local copy = types.copy(tbl)
		for key, property in copy:properties() do
			copy:setproperty(key, property.read or property.write)
		end

		return copy
	end

	if t:is("union") then
		local components = t:components()
		local writeable_components = table.create(#components) :: { type }
		for index, component in components do
			writeable_components[index] = make_writeable(component)
		end
		return types.unionof(table.unpack(writeable_components))
	elseif t:is("table") then
		return make_writeable(t)
	else
		error("Expected a table or union type")
	end
end

export type function Drop(union: type, value: type)
	local components = union:components()
	for index = #components, 1, -1 do
		local component = components[index]
		if component == value then
			table.remove(components, index)
		end
	end
	return types.unionof(table.unpack(components))
end

return nil
