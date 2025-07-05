local compiler = require("@compiler/")
local fs = require("@lune/fs")
local path = require("@util/path")

local input_path = path.from_string("./blink/bench.blink")
input_path = path.to_absolute_path(input_path)

local result = compiler.compile_from_path(input_path, {
	time = false,
	verbose = false,
	profile = "dev",
})

assert(result)
fs.writeFile("./out/output.luau", result.targets.shared)
