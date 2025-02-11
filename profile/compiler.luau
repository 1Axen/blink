local fs = require("@lune/fs")
local serde = require("@lune/serde")

local path = require("@util/path")
local file = require("@util/file")
local compiler = require("@compiler/")

local input_path = path.from_string("./blink/bench.blink")
input_path = path.to_absolute_path(input_path)

compiler.compile_from_path(input_path, {
    time = false,
    verbose = false,
    profile = "dev"
})