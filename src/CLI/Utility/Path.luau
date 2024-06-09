--!strict

---- Imports ----

local fs = require("@lune/fs")

---- Settings ----

local EXTENSIONS = {"", ".txt", ".blink"}

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Utility.GetDefinitionFilePath(Path: string): string
    for _, Extension in EXTENSIONS do
		local Temporary = `{Path}{Extension}`
		if fs.isFile(Temporary) then
			return Temporary
		end
	end

	return Path
end

function Utility.ExtractDirectoryFromPath(Path: string): string
    return string.match(Path, ".+/") or "./"
end

---- Initialization ----

---- Connections ----

return Utility