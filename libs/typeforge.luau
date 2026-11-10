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
	local function make_writeable(frozen: type)
		if not frozen:is("table") then
			return frozen
		end

		local writeable = types.copy(frozen)
		for key, property in writeable:properties() do
			if property.read and property.write == nil then
				writeable:setproperty(key, property.read)
			end
		end

		return writeable
	end

	if t:is("union") then
		local components = t:components()
		local writeable_components = table.create<<type>>(#components)
		for index, component in components do
			writeable_components[index] = make_writeable(component)
		end
		return types.unionof(table.unpack(writeable_components))
	end

	return make_writeable(t)
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

export type function Pick(union: type, tag: type)
	for _, variant in union:components() do
		const kind = variant:readproperty(types.singleton("kind"))
		if kind == nil then
			error("all variants must have a kind property")
		end

		if kind:issubtypeof(tag) then
			return variant
		end
	end
	return types.unknown
end

export type function NonNil(t: type)
	if not t:is("union") then
		return t
	end

	local components = t:components()
	local new_components = table.create<<type>>(#components)

	for _, component in components do
		if component.tag ~= "nil" then
			table.insert(new_components, component)
		end
	end

	if #new_components == 0 then
		return types.singleton(nil)
	elseif #new_components == 1 then
		return new_components[1]
	end

	return types.unionof(table.unpack(new_components))
end

export type function ConcatStringletonUnions(left: type, right: type)
	local concatenated = {}
	local right_components = right:components()
	for _, left_singleton in left:components() do
		const left_value = left_singleton:value()
		assert(typeof(left_value) == "string", "expected left union to be of only stringletons")

		for _, right_singleton in right_components do
			const right_value = right_singleton:value()
			assert(typeof(right_value) == "string", "expected right union to be of only stringletons")

			table.insert(concatenated, types.singleton(left_value .. right_value))
		end
	end

	return types.unionof(table.unpack(concatenated))
end

export type function CastUnknownToAny(x: type)
	if x:is("unknown") then
		return types.any
	end

	return x
end

return nil
