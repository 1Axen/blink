local fs = require("@lune/fs")
local log = require("./libs/log")
local process = require("@lune/process")

type Archs = 
    | "aarch64"
    | "x86_64"

type Platforms =
    | "macos"
    | "linux"
    | "windows"



local EXE_NAME = "blink"

local RELEASE_DIR = "release"
local PLUGIN_SOURCE_DIR = `plugin/src`
local PLUGIN_RELEASE_DIR = `{RELEASE_DIR}/plugin`

local CLI_PATH = "src/CLI/init.luau"
local BUNDLE_PATH = `{RELEASE_DIR}/blink.luau`

local DARKLUA_CONFIG = "build/.darklua.json"
local PLUGIN_ROJO_CONFIG = "build/plugin.project.json"

local function build_executable(platform: Platforms, arch: Archs)
    local target = `{platform}-{arch}`
    local exe_name = `{EXE_NAME}{platform == "windows" and ".exe" or ""}`
    local exe_path = `{RELEASE_DIR}/{exe_name}`
    local build_result = process.spawn("lune", {
        "build", 
        BUNDLE_PATH, 
        "--output", exe_path, 
        "--target", target
    }, {stdio = "forward"})
    assert(build_result.ok, build_result.stderr)

    local archive_result = process.spawn("tar", {
        "-cavf",
        `{RELEASE_DIR}/blink-{target}.zip`,
        "-C",
        RELEASE_DIR,
        exe_name
    }, {stdio = "forward"})
    assert(archive_result.ok, archive_result.stderr)

    fs.removeFile(exe_path)
    log(`Built executable for {target}`)
end

local function build_executables()
    local bundle_result = process.spawn("darklua", {"process", "--config", DARKLUA_CONFIG, CLI_PATH, BUNDLE_PATH})
    assert(bundle_result.ok, bundle_result.stderr)
    log("Bundled CLI source code")

    build_executable("macos", "x86_64")
    build_executable("macos", "aarch64")
    build_executable("linux", "x86_64")
    build_executable("linux", "aarch64")
    build_executable("windows", "x86_64")

    fs.removeFile(BUNDLE_PATH)
end

local function build_studio_plugin()
    fs.writeDir(PLUGIN_RELEASE_DIR)
    
    for _, filename in fs.readDir(PLUGIN_SOURCE_DIR) do
        if string.split(filename, ".")[2] == "rbxmx" then
            fs.copy(`{PLUGIN_SOURCE_DIR}/{filename}`, `{PLUGIN_RELEASE_DIR}/{filename}`)
        end
    end

    local bundle_result = process.spawn("darklua", {
        "process", 
        "--config", 
        DARKLUA_CONFIG, 
        `{PLUGIN_SOURCE_DIR}/init.server.luau`, 
        `{PLUGIN_RELEASE_DIR}/init.server.luau`
    })
    assert(bundle_result.ok, bundle_result.stderr)

    local rojo_result = process.spawn("rojo", {
        "build", 
        PLUGIN_ROJO_CONFIG, 
        "--output", 
        `{RELEASE_DIR}/blink-plugin.rbxm`
    })
    assert(rojo_result.ok, rojo_result.stderr)

    log("Built studio plugin")
    fs.removeDir(PLUGIN_RELEASE_DIR)
end

do
    if fs.isDir(RELEASE_DIR) then
        fs.removeDir(RELEASE_DIR)
    end
    fs.writeDir(RELEASE_DIR)
end

local start = os.clock()
build_executables()
build_studio_plugin()

local elapsed = (os.clock() - start)
print(string.format("Finished build in %.2f seconds", elapsed))