--!strict

---- Imports ----

local PathParser = require("../../Modules/Path")
local fs = require("@lune/fs")

---- Settings ----

local EXTENSIONS = { "", ".txt", ".blink" }

return function(Path: string): string
	local Directory, Filename = PathParser.Components(Path)
	Directory = Directory or "./"
	assert(Filename, `Unable to parse filename from {Path}, path may be malformed!`)

	for _, Extension in EXTENSIONS do
		local Temporary = `{Directory}{Filename}{Extension}`
		if fs.isFile(Temporary) then
			return Temporary
		end
	end

	return Path
end
