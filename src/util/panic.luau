local style = require("@util/style")

local NOTE = `{style.color.green("NOTE")}:`
local HELPFUL_INFORMATION = `{NOTE} Blink unexpectedly panicked. This is a bug.\n{NOTE} Please file a bug report at: https://github.com/1Axen/blink/issues`

local function collect_info(): string
    local build_date = _G.BUILD_DATE or "N/A"
    local build_version = _G.BUILD_VERSION or "dev"

    local platform = "ROBLOX"
    if game == nil then
        local process = require("@lune/process")
        platform = `{process.arch}-{process.os}`
    end

    return `blink {build_version} ({build_date}) running on {platform}`
end

return function(step: string)
    local function panic(final_words: string): never
        local info = collect_info()
        local source, name, line = debug.info(2, "snl")
        local panic_message = `{step} panicked at {source}.{name}:{line}: {final_words}`
        panic_message ..= `\n\n{HELPFUL_INFORMATION}`
        panic_message ..= `\n{NOTE} {info}`

        error(panic_message)
    end

    return panic
end
