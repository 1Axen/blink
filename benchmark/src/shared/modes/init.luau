local Modes = {}
for Index, Mode in script:GetChildren() do
    Modes[Mode.Name] = require(Mode)
end

--> Warp seems to be broken?
Modes.warp = nil

return Modes
