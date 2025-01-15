export type Runtime = "ROBLOX" | "Lune"

local function get_runtime(): Runtime
    if typeof(game) == "Instance" then
        return "ROBLOX"
    end

    return "Lune"
end

return get_runtime
