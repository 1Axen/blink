local Modes = {}
for Index, Mode in script:GetChildren() do
    Modes[Mode.Name] = require(Mode)
end
return Modes
