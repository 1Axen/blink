--!strict

---- Imports ----

---- Settings ----

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Utility.Components(Path: string): (string?, string?, string?)
	local Filename: string?;
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

---- Initialization ----

---- Connections ----

return Utility