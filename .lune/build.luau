local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

type Archs = 
    | "aarch64"
    | "x86_64"

type Platforms =
    | "macos"
    | "linux"
    | "windows"

type DarkluaRules = 
    | "inject_global_value"
    | "N/A"

type DarkluaConfig = {
    rules: {
        DarkluaRules | {
            rule: DarkluaRules,
            identifier: string,
            value: any
        }
    }
}

local EXE_NAME = "blink"

local RELEASE_DIR = "./release"
local PLUGIN_SOURCE_DIR = `./plugin/src`
local PLUGIN_RELEASE_DIR = `{RELEASE_DIR}/plugin`

local CLI_PATH = "src/CLI/init.luau"
local BUNDLE_PATH = `{RELEASE_DIR}/blink_cli.luau`

local DARKLUA_CONFIG = "./build/.darklua.json"
local PLUGIN_ROJO_CONFIG = "./build/plugin.project.json"

local function log_step(text: string)
    print(`* {text}`)
end

local function update_darklua_version(version: string)
    local contents = fs.readFile(DARKLUA_CONFIG)
    local config = serde.decode("json", contents) :: DarkluaConfig

    for _, rule in config.rules do
        if type(rule) == "string" then
            continue
        end

        if rule.rule ~= "inject_global_value" then
            continue
        end

        if rule.identifier == "VERSION" then
            rule.value = version
        end
    end

    contents = serde.encode("json", config, true)
    fs.writeFile(DARKLUA_CONFIG, contents)
    log_step(`Updated darklua config version to {version}`)
end

local function build_executable(version: string, platform: Platforms, arch: Archs)
    local target = `{platform}-{arch}`
    local exe_name = `{RELEASE_DIR}/{EXE_NAME}`
    if platform == "windows" then
        exe_name ..= ".exe"
    end

    local build_result = process.spawn("lune", {
        "build", 
        BUNDLE_PATH, 
        "--output", exe_name, 
        "--target", target
    })
    assert(build_result.ok, build_result.stderr)

    local archive_name = `blink-{version}-{target}.zip`
    local archive_result = process.spawn("tar", {
        "-a", 
        "-c", 
        "-f", 
        archive_name, 
        `{EXE_NAME}.*`
    }, {
        cwd = `{process.cwd}/{RELEASE_DIR}`
    })
    assert(archive_result.ok, archive_result.stderr)

    fs.removeFile(exe_name)
    log_step(`Built executable for {target}`)
end

local function build_executables(version: string)
    local bundle_result = process.spawn("darklua", {"process", "--config", DARKLUA_CONFIG, CLI_PATH, BUNDLE_PATH})
    assert(bundle_result.ok, bundle_result.stderr)
    log_step("Bundled CLI source code")

    build_executable(version, "macos", "x86_64")
    build_executable(version, "macos", "aarch64")
    build_executable(version, "linux", "x86_64")
    build_executable(version, "linux", "aarch64")
    build_executable(version, "windows", "x86_64")

    fs.removeFile(BUNDLE_PATH)
end

local function build_studio_plugin(version: string)
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
        `{RELEASE_DIR}/blink-{version}-plugin.rbxm`
    })
    assert(rojo_result.ok, rojo_result.stderr)

    log_step("Built studio plugin")
    fs.removeDir(PLUGIN_RELEASE_DIR)
end

do
    if fs.isDir(RELEASE_DIR) then
        fs.removeDir(RELEASE_DIR)
    end
    fs.writeDir(RELEASE_DIR)
end

local version = stdio.prompt("text" :: "text", "What version is being built?")

local start = os.clock()
update_darklua_version(version)
build_executables(version)
build_studio_plugin(version)

local elapsed = (os.clock() - start)
print(string.format("Finished build in %.2f seconds", elapsed))