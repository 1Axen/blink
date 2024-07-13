--> Temporary file used for tracking performance with every change

local fs = require("@lune/fs")
local date_time = require("@lune/datetime")
local lexer = require("compiler/lexer")

local function fs_append(path: string, text: string)
    local contents = fs.readFile(path)
    fs.writeFile(path, contents .. text)
end

local function format_seconds(seconds: number): string
    local suffix = "seconds"
	if seconds < 1E-6 then
        seconds *= 1E+9
        suffix = "ns"
	elseif seconds < 0.001 then
        seconds *= 1E+6
        suffix = "μs"
	elseif seconds < 1 then
        seconds *= 1000
        suffix = "ms"
	end

    return string.format("%.2f %s", seconds, suffix)
end

local function benchmark_closure(name: string, closure: () -> ())
    local start = os.clock()
    closure()

    local elapsed = (os.clock() - start)
    local date_time_now = date_time.now()

    fs_append("performance.txt", `\n{date_time_now:toIsoDate()} - {name} - {format_seconds(elapsed)}`)
end

local code = fs.readFile("../test/Sources/Test.txt")
benchmark_closure("lexer", function()
    lexer.tokenize(code)
end)
