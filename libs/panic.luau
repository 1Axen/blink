local style = require("@util/style")
local runtime = require("@util/runtime")

local NOTE = `{style.color.green("NOTE")}:`
local RUNTIME = runtime()
local HELPFUL_INFORMATION = `{NOTE} Blink unexpectedly panicked. This is a bug.\n{NOTE} Please file a bug report at: https://github.com/1Axen/blink/issues`

local function collect_info(): string
    local build_date = _G.BUILD_DATE or "N/A"
    local build_version = _G.BUILD_VERSION or "dev"

    local platform = "ROBLOX"
    if RUNTIME == "Lune" then
        local process = require("@lune/process")
        platform = `{process.arch}-{process.os}`
    end

    return `blink {build_version} ({build_date}) running on {platform}`
end

return function(final_words: string): never
    local info = collect_info()
    -- SOLVER BUG
    local source: string, name: string, line: number = (debug.info :: any)(2, "snl")

    local panic_message = `{source}:{line}: panicked in {name}:{line}: {final_words}`
    panic_message ..= `\n\n{HELPFUL_INFORMATION}`
    panic_message ..= `\n{NOTE} {info}`

    return error(panic_message)
end
