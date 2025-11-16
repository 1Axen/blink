export type Runtime = "ROBLOX" | "Standalone"

local function get_runtime(): Runtime
	if typeof(game) == "Instance" then
		return "ROBLOX"
	end

	return "Standalone"
end

return get_runtime
