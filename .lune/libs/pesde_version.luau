local fs = require("@lune/fs")
local log = require("./log")
local serde = require("@lune/serde")

type PesdeConfig = {
	version: string,
}

local function read_version(config_path: string): string
	local contents = fs.readFile(config_path)
	local config = serde.decode("toml", contents) :: PesdeConfig
	return config.version or "?"
end

local function write_version(config_path: string, version: string)
	local contents = fs.readFile(config_path)
	local config = serde.decode("toml", contents) :: PesdeConfig

	config.version = version
	contents = serde.encode("toml", config, true)
	fs.writeFile(config_path, contents)

	log(`Updated pesde config version to {version}`)
end

return table.freeze({
	read_from = read_version,
	write_to = write_version,
})
