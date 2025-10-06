local compiler = require("@compiler/")
local fs = require("@lune/fs")
local path = require("@util/path")
local process = require("@lune/process")

local file = `blink/{process.args[1] or "bench"}.blink`
local input_path = path.from_string(file)
input_path = path.to_absolute_path(input_path)

local result = compiler.compile_from_path(input_path, {
	time = false,
	verbose = false,
	profile = "dev",
})

assert(result)

if fs.isDir("./out") == false then
	fs.writeDir("./out")
end

fs.writeFile("./out/output_types.luau", result.targets.shared)
fs.writeFile("./out/output_client.luau", result.targets.client)
fs.writeFile("./out/output_server.luau", result.targets.server)
