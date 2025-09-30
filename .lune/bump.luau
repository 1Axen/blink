local stdio = require("@lune/stdio")
local blink_version = require("./libs/blink_version")

local DARKLUA_CONFIG = "build/.darklua.json"

local curr_version = blink_version.read_from(DARKLUA_CONFIG)
local new_version = stdio.prompt("text" :: "text", `What version is being built? (Current version is {curr_version})`)
blink_version.write_to(DARKLUA_CONFIG, new_version)