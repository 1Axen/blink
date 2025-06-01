local types = require("@self/types")
local RUNTIME = require("@util/runtime")()

export type IOError = types.IOError
export type Metadata = types.Metadata
export type MetadataPermissions = types.MetadataPermissions

return if RUNTIME == "ROBLOX" 
    then require("@self/roblox") :: types.API 
    else require("@self/lune") :: types.API