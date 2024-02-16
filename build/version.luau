local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local DarkluaConfig = fs.readFile("./.darklua.json")
local JsonConfig = net.jsonDecode(DarkluaConfig)

local Version = process.args[1]

local Rules = JsonConfig.rules
local VersionGlobal = Rules[5]

if VersionGlobal.identifier ~= "VERSION" then
    error("Rules were shifted, update the build script.")
end

VersionGlobal.value = Version
fs.writeFile("./.darklua.json", net.jsonEncode(JsonConfig, true))
print(`Updated darklua config version to {Version}`)