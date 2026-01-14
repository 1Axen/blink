local fs = require("@std/fs")
local log = require("./libs/log")
local process = require("@lute/process")
local system = require("@lute/system")

local EXE_NAME = "blink"
local RELEASE_DIR = "./release"
local CLI_PATH = "./cli/init.luau"

local function build_executable()
	local is_windows = system.os == "Windows_NT"
	local exe_name = `{EXE_NAME}{is_windows and ".exe" or ""}`
	local exe_path = `{RELEASE_DIR}/{exe_name}`

	local run_result = process.run({
		"lute",
		"compile",
		CLI_PATH,
		"--output",
		exe_path,
	})

	assert(run_result.ok, run_result.stderr)

	local archive_result: process.ProcessResult
	if is_windows then
		archive_result = process.run({
			"tar",
			"-czvf",
			`{RELEASE_DIR}/blink.tar.gz`,
			"-C",
			RELEASE_DIR,
			exe_name,
		})
	else
		archive_result = process.run({
			"tar",
			"-cJvf",
			`{RELEASE_DIR}/blink.tar.xz`,
			"-C",
			RELEASE_DIR,
			exe_name,
		})
	end

	assert(archive_result.ok, archive_result.stderr)

	fs.remove(exe_path)
	log(`Built executable to {RELEASE_DIR}/blink.tar.*`)
end

do
	if fs.exists(RELEASE_DIR) then
		fs.removedirectory(RELEASE_DIR, { recursive = true })
	end
	fs.createdirectory(RELEASE_DIR)
end

local start = os.clock()
build_executable()

local elapsed = (os.clock() - start)
print(string.format("Finished build in %.2f seconds", elapsed))
