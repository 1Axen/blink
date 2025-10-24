local darklua_version = require("./libs/darklua_version")
local pesde_version = require("./libs/pesde_version")
local stdio = require("@lune/stdio")

local PESDE_CONFIG = "pesde.toml"
local DARKLUA_CONFIG = "build/.darklua.json"

local curr_version = darklua_version.read_from(DARKLUA_CONFIG)
local new_version = stdio.prompt("text" :: "text", `What version is being built? (Current version is {curr_version})`)
darklua_version.write_to(DARKLUA_CONFIG, new_version)
pesde_version.write_to(PESDE_CONFIG, new_version)
