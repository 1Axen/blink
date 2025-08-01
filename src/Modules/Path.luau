--!strict

---- Imports ----

---- Settings ----

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Utility.PathType(Path: string): "absolute" | "relative"
	-- on unix-based systems, '/' is root
	if string.sub(Path, 1, 1) == "/" then
		return "absolute"
	end

	-- on windows systems, it is %w:[\\/]
	if string.sub(Path, 2, 2) == ":" then
		return "absolute"
	end

	return "relative"
end

function Utility.Components(Path: string): (string?, string?, string?)
	local Filename: string?
	local Directory, FilenameExt, Extension = string.match(Path, "(.-)([^\\/]-%.?([^%.\\/]*))$")

	if FilenameExt then
		if FilenameExt == Extension then
			Extension = nil
			Filename = FilenameExt
		elseif Extension then
			Filename = string.sub(FilenameExt, 1, #FilenameExt - (#Extension + 1))
		end
	end

	return Directory, Filename, Extension
end

function Utility.Filename(Path: string): string?
	local _, Filename = Utility.Components(Path)
	return Filename
end

function Utility.Directory(Path: string): string?
	local Directory = Utility.Components(Path)
	return Directory
end

function Utility.Extension(Path: string): string?
	local _, _, Extension = Utility.Components(Path)
	return Extension
end

function Utility.NameWithExtension(Path: string): string?
	local _, Name, Extension = Utility.Components(Path)
	if Name and Extension then
		return `{Name}.{Extension}`
	end

	return
end

---- Initialization ----

---- Connections ----

return Utility
