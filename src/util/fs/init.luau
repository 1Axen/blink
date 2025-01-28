local types = require("./types")
local RUNTIME = require("@util/runtime")()

export type IOError = types.IOError

return if RUNTIME == "ROBLOX" 
    then require("./roblox") :: types.API 
    else require("./lune") :: types.API