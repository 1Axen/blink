--> Temporary file used for tracking performance with every change

local fs = require("@lune/fs")
local date_time = require("@lune/datetime")
local lexer = require("../src/compiler/lexer")

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
    local time_sum = 0
    for _ = 1, 1_000 do
        local start = os.clock()

        closure()

        local elapsed = (os.clock() - start)
        time_sum += elapsed
    end

    local average_time = time_sum / 1_000
    local text_result = `{date_time.now():formatLocalTime()} - {name} - {format_seconds(average_time)}`
    
    print(text_result)
    fs_append("performance.txt", `\n{text_result}`)
end

local small_code = fs.readFile("blink/small.blink")
local large_code = fs.readFile("blink/large.blink")

benchmark_closure("lexer small.blink", function()
    lexer.tokenize(small_code)
end)

benchmark_closure("lexer large.blink", function()
    lexer.tokenize(large_code)
end)