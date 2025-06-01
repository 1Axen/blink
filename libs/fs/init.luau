local RUNTIME = require("@util/runtime")()
local types = require("@self/types")

export type IOError = types.IOError
export type Metadata = types.Metadata
export type MetadataPermissions = types.MetadataPermissions

--stylua: ignore
return if RUNTIME == "ROBLOX" 
    then require("@self/roblox") :: types.API 
    else require("@self/lune") :: types.API