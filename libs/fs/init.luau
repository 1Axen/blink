local types = require("./types")
local RUNTIME = require("@util/runtime")()

export type IOError = types.IOError
export type Metadata = types.Metadata
export type MetadataPermissions = types.MetadataPermissions

return if RUNTIME == "ROBLOX" 
    then require("./roblox") :: types.API 
    else require("./lune") :: types.API