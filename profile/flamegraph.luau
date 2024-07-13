local fs = require("@lune/fs")
local process = require("@lune/process")

local LuauResult = process.spawn("luau/luau.exe", {"--profile", "simple.luau"}, {cwd = process.cwd})
assert(LuauResult.ok, LuauResult.stderr)

local PythonResult = process.spawn("python", {"luau/perfgraph.py", "profile.out"}, {cwd = process.cwd})
assert(PythonResult.ok, PythonResult.stderr)

fs.writeFile("luau/profile.svg", PythonResult.stdout)
fs.removeFile("profile.out")

print("Flamegraph generated!")

local OpenResult = process.spawn("cmd", {"/C", "start", "luau/profile.svg"}, {shell = true})
assert(OpenResult.ok, OpenResult.stderr)

print("Flamegraph opened!")