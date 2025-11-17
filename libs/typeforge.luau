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

return nil
