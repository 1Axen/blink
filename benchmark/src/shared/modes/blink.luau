local RunService = game:GetService("RunService")
if RunService:IsServer() then
    return require("../blink/Server")
elseif RunService:IsClient() then
    return require("../blink/Client")
end