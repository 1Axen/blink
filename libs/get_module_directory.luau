local function get_module_path(): string
	local source: string = debug.info(2, "s") :: string

	local path = string.sub(source, 10, #source - 2)
	path = string.gsub(path, "\\", "/")

	local segments = string.split(path, "/")
	return table.concat(segments, "/", 1, #segments - 1)
end

return get_module_path
