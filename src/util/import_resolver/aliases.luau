local result = require("@util/result")
local option = require("@util/option")

-- lune
local fs: typeof(require("@lune/fs"));
local luaurc: typeof(require("@util/luaurc"));

export type Aliases = {[string]: string}
type Result<T, E> = result.Result<T, E>

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
    luaurc = require("@util/luaurc")
end

local function aliases_from_path(path: string): Result<Aliases, ConfigError>
    local io_success, json_contents = pcall(function()
        return fs.readFile(path)
    end)

    if io_success == false then
        return result.err("IOError" :: IOError)
    end

    local luaurc_result = luaurc.from_json(json_contents)
    if luaurc_result.error then
        return result.err("ParseError" :: ParseError)
    end

    local aliases_opt = luaurc.aliases(luaurc_result.value)
    local aliases = option.unwrap_or(aliases_opt, {}) :: Aliases

    return result.ok(aliases)
end

--- Unimplemented for now
local function collect_roblox_aliases(): Aliases
    return {}
end

--- Implemented according to https://github.com/luau-lang/rfcs/blob/master/docs/require-by-string-aliases.md 
local function collect_fs_aliases(directory: string): Aliases
    import_std()

    local all_aliases: Aliases = {}
    local current_directory = directory

    local function record_unique_aliases(aliases: Aliases)
        for alias, luaurc_relative_path in aliases do
            if all_aliases[alias] then
                continue
            end

            local file_relative_path = `{current_directory}/{luaurc_relative_path}`
            all_aliases[alias] = file_relative_path 
        end
    end

    while fs.isDir(current_directory) do
        local path = `{current_directory}/{luaurc.CONFIG_NAME}`
        if fs.isFile(path) then
            local aliases_result = aliases_from_path(path)
            if aliases_result.value then
                record_unique_aliases(aliases_result.value :: Aliases)
            end
        end

        current_directory ..= "/.."
    end

    return all_aliases
end

return table.freeze({
    fs = collect_fs_aliases,
    roblox = collect_roblox_aliases
})