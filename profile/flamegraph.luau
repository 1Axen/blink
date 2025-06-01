local fs = require("@lune/fs")
local process = require("@lune/process")

local file_source = fs.readFile("./blink/large.blink")
local luau_source =
	`--!native\n--!optimize 2\nlocal lexer = require("../../src/compiler/lexer")\nlocal source = [[{file_source}]]\nlexer.tokenize(buffer.fromstring(source))`
fs.writeFile("./out/bench.luau", luau_source)

local darklua_result = process.exec(
	"darklua",
	{ "process", "--config", "./config/bench.darklua.json", "./out/bench.luau", "./out/bench.luau" }
)
assert(darklua_result.ok, darklua_result.stderr)

local LuauResult = process.exec(
	"luau/luau.exe",
	{ "--codegen", "-O2", "--profile", "./out/bench.luau" },
	{ cwd = process.cwd }
)
assert(LuauResult.ok, LuauResult.stderr)

local PythonResult = process.exec("python", { "luau/perfgraph.py", "profile.out" }, { cwd = process.cwd })
assert(PythonResult.ok, PythonResult.stderr)

fs.writeFile("out/profile.svg", PythonResult.stdout)
fs.removeFile("profile.out")

print("Flamegraph generated!")

local OpenResult = process.exec("powershell", { "-c", '"./out/profile.svg"' }, { shell = true })
assert(OpenResult.ok, OpenResult.stderr)

print("Flamegraph opened!")
