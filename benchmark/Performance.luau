local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local Lexer = require("../src/Lexer")
local Parser = require("../src/Parser")
local Generator = require("../src/Generator")

local Source = fs.readFile("../test/Sources/Test.txt")
local SourceLexer = Lexer.new()
local SourceParser = Parser.new("../test/Sources/")
local AbstractSyntaxTree = SourceParser:Parse(Source)

local function Format(Time: number): string
    local Suffix = "seconds"
	if Time < 1E-6 then
        Time *= 1E+9
        Suffix = "ns"
	elseif Time < 0.001 then
        Time *= 1E+6
        Suffix = "μs"
	elseif Time < 1 then
        Time *= 1000
        Suffix = "ms"
	end

    return `{stdio.color("green")}{string.format("%.2f", Time)} {Suffix}{stdio.color("reset")}`
end

local function Percentile(Samples: {number}, Percent: number): number
    local Index = (#Samples * Percent) // 1
    Index = math.max(Index, 1)
    return Samples[Index]
end

local function BenchmarkClosure(Title: string, Closure: () -> ())
    print(`Benchmarking: {Title}`)
    stdio.write("Running")

    local Times = {}
    for Index = 1, 1_000 do
        stdio.write(`\rRunning [{stdio.color("green")}{Index}{stdio.color("reset")}/1000]`)

        local Start = os.clock()
        Closure()

        local Elapsed = (os.clock() - Start)
        table.insert(Times, Elapsed)
    end
    
    table.sort(Times, function(a, b)
        return a < b
    end)
    
    stdio.write(`\r-------- {stdio.color("yellow")}{Title}{stdio.color("reset")} --------\n`)
    print(`Median: {Format(Percentile(Times, 0.5))}`)
    print(`0th Percentile: {Format(Times[1])}`)
    print(`90th Percentile: {Format(Percentile(Times, 0.9))}`)
    print(`95th Percentile: {Format(Percentile(Times, 0.95))}`)
end

_G.BUNDLED = true
_G.VERSION = "PERFROMANCE"

BenchmarkClosure("Lex", function()
    SourceLexer:Initialize(Source)

    while true do
        local Token = SourceLexer:GetNextToken()
        if Token.Type == "EndOfFile" then
            break
        end
    end
end)

BenchmarkClosure("Parse", function()
    SourceParser:Parse(Source)
end)

BenchmarkClosure("Generate", function()
    Generator.Generate("Server", AbstractSyntaxTree)
end)
