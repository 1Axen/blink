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

return nil
