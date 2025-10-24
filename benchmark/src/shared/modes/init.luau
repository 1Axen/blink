local DISABLED_MODES = {
	warp = true,
}

local Modes = {}
for Index, Mode in script:GetChildren() do
	if DISABLED_MODES[Mode.Name] then
		continue
	end

	Modes[Mode.Name] = require(Mode)
end

return Modes
