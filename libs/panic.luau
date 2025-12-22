local runtime = require("@util/runtime")
local string_builder = require("@util/string_builder")
local style = require("@util/style")

local NOTE = `{style.color.green("NOTE")}:`
local TRACE = `{style.color.purple("TRACE")}:`
local HELPFUL_INFORMATION = {
	`{NOTE} Blink unexpectedly panicked. This is a bug.`,
	`{NOTE} Please file a bug report at: https://github.com/1Axen/blink/issues`,
}

local RUNTIME = runtime()

local function collect_info(): string
	local build_date = _G.BUILD_DATE or "N/A"
	local build_version = _G.BUILD_VERSION or "dev"

	local platform = "ROBLOX"
	if RUNTIME == "Standalone" then
		local system = require("@lute/system")
		platform = `{system.arch}-{system.os}`
	end

	return `blink {build_version} ({build_date}) running on {platform}`
end

return function(final_words: string): never
	local info = collect_info()
	local trace = debug.traceback(nil, 2)
	-- SOLVER BUG
	local name: string, line: number = (debug.info :: any)(2, "nl")
	local panic_builder = string_builder.create({})

	panic_builder:append_line(`panicked in {name}:{line}: {final_words}`)
	panic_builder:append_line("")
	panic_builder:append_lines(HELPFUL_INFORMATION)
	panic_builder:append_line(`{NOTE} {info}`)
	panic_builder:append_line(TRACE)
	panic_builder:append_lines(string.split(trace, "\n"))

	return error(panic_builder:finalize(), 2)
end
