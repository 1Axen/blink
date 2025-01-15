local result = require("@util/result")

-- lune
local fs: typeof(require("@lune/fs"));
local serde: typeof(require("@lune/serde"))

export type Aliases = {[string]: string}

type Result<T, E> = result.Result<T, E>
type LuaurcSchema = {
    aliases: Aliases
}

local LUAURC_CONFIG = ".luaurc"

type IOError = "IOError"
type ParseError = "ParseError"
type ConfigError = 
    IOError 
    | ParseError
;

local function import_std()
    if fs ~= nil then
        return
    end

    fs = require("@lune/fs")
    serde = require("@lune/serde")
end

local function get_aliases(config_path: string): Result<Aliases, ConfigError>
    local io_success, json = pcall(function()
        return fs.readFile(config_path)
    end)

    if io_success == false then
        return result.err("IOError" :: IOError)
    end

    local parse_success, schema = pcall(function()
        return serde.decode("json", json) :: LuaurcSchema
    end)

    if parse_success == false then
        return result.err("ParseError" :: ParseError)
    end

    return result.ok(schema.aliases)
end

--- Unimplemented for now
local function collect_roblox_aliases(): Aliases
    return {}
end

--- Implemented according to https://github.com/luau-lang/rfcs/blob/master/docs/require-by-string-aliases.md 
local function collect_fs_aliases(directory: string): Aliases
    import_std()

    local aliases: Aliases = {}
    local current_directory = directory

    while fs.isDir(current_directory) do
        local path = `{current_directory}/{LUAURC_CONFIG}`
        if fs.isFile(path) then
            local config_aliases = get_aliases(path)
            if config_aliases.value then
                for alias, config_relative_path in config_aliases.value do
                    if aliases[alias] then
                        continue
                    end
        
                    local file_relative_path = `{current_directory}/{config_relative_path}`
                    aliases[alias] = file_relative_path 
                end
            end
        end

        current_directory ..= "/.."
    end

    return aliases
end

return table.freeze({
    fs = collect_fs_aliases,
    roblox = collect_roblox_aliases
})