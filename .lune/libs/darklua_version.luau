local fs = require("@lune/fs")
local serde = require("@lune/serde")
local log = require("./log")

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

local function read_version(config_path: string): string
    local contents = fs.readFile(config_path)
    local config = serde.decode("json", contents) :: DarkluaConfig

    for _, rule in config.rules do
        if type(rule) == "string" then
            continue
        end

        if rule.rule ~= "inject_global_value" then
            continue
        end

        if rule.identifier == "VERSION" then
            return rule.value
        end
    end

    return "?"
end

local function write_version(config_path: string, version: string)
    local contents = fs.readFile(config_path)
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
    fs.writeFile(config_path, contents)
    log(`Updated darklua config version to {version}`)
end

return table.freeze({
    read_from = read_version,
    write_to = write_version
})