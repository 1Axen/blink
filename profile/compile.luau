local compiler = require("@compiler/")
local fs = require("@lute/fs")
local path = require("@util/path")

local args = { ... }
local file = `blink/{args[2] or "bench"}.blink`
local input_path = path.from_string(file)
input_path = path.to_absolute_path(input_path)

local result = compiler.compile_from_path(input_path, {
	time = false,
	verbose = false,
	profile = "dev",
})

assert(result)

if fs.exists("./out") == false then
	fs.mkdir("./out")
end

fs.writestringtofile("./out/output_types.luau", result.targets.shared)
fs.writestringtofile("./out/output_client.luau", result.targets.client)
fs.writestringtofile("./out/output_server.luau", result.targets.server)
