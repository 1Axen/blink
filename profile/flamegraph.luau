local fs = require("@lute/fs")
local process = require("@lute/process")

local file_source = fs.readfiletostring("./blink/large.blink")
local luau_source =
	`--!native\n--!optimize 2\nlocal lexer = require("../../src/compiler/lexer")\nlocal source = [[{file_source}]]\nlexer.tokenize(buffer.fromstring(source))`
fs.writestringtofile("./out/bench.luau", luau_source)

local darklua_result = process.run({
	"darklua",
	"process",
	"--config",
	"./config/bench.darklua.json",
	"./out/bench.luau",
	"./out/bench.luau",
})
assert(darklua_result.ok, darklua_result.stderr)

local LuauResult = process.run({ "luau/luau.exe", "--codegen", "-O2", "--profile", "./out/bench.luau" })
assert(LuauResult.ok, LuauResult.stderr)

local PythonResult = process.run({ "python", "luau/perfgraph.py", "profile.out" })
assert(PythonResult.ok, PythonResult.stderr)

fs.writestringtofile("out/profile.svg", PythonResult.stdout)
fs.remove("profile.out")

print("Flamegraph generated!")

local OpenResult = process.run({ "powershell", "-c", '"./out/profile.svg"' }, { shell = true })
assert(OpenResult.ok, OpenResult.stderr)

print("Flamegraph opened!")
