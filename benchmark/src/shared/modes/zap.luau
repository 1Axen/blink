local RunService = game:GetService("RunService")
if RunService:IsServer() then
    return require("../zap/Server")
elseif RunService:IsClient() then
    return require("../zap/Client")
end