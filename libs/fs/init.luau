local RUNTIME = require("@util/runtime")()
local types = require("@self/types")

export type IOError = types.IOError
export type Metadata = types.Metadata
export type MetadataPermissions = types.MetadataPermissions

--stylua: ignore
return (if RUNTIME == "ROBLOX" 
    then require("@self/roblox")
    else require("@self/standalone")) :: types.API