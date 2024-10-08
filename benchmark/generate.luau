local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local DateTime = require("@lune/datetime")

local VersionsJSON = fs.readFile("./tools/versions.json")
local Versions = net.jsonDecode(VersionsJSON)

local RobloxResult = process.spawn("run-in-roblox", {"--place", "Benchmark.rbxl", "--script", "run.luau"})
if not RobloxResult.ok then
    error(RobloxResult.stderr)
end

local Stdout = string.split(RobloxResult.stdout, "--RESULTS JSON--")
table.remove(Stdout, 1)

local Result: {[string]: {[string]: Benchmark}};
for _, Line in Stdout do
    Line = string.gsub(Line, "\n", "")
    if string.sub(Line, 1, 1) == "{" then
        Result = net.jsonDecode(Line)
        break 
    end
end

local Seperator = "*The tables below were automatically generated by this [script](https://github.com/1Axen/Blink/blob/main/benchmark/generate.luau).*"
local Header = string.split(fs.readFile("./Benchmarks.md"), Seperator)
local Contents = Header[1] .. Seperator

Contents ..= `\n## Last Updated {DateTime.now():formatUniversalTime()} UTC`
Contents ..= `\n## Tool Versions`

for Tool, Version in Versions do
    Contents ..= `\n\`{Tool}\`: {Version}  `
end

local function QueryWMIC(Component: string, Properties: string): {string}
    local SpawnResult = process.spawn("wmic", {Component, "get", Properties})
    assert(SpawnResult.ok, SpawnResult.stderr)

    local Lines = string.split(SpawnResult.stdout, "\n")

    --> Remove header and padding
    table.remove(Lines, 1)
    table.remove(Lines, #Lines)
    table.remove(Lines, #Lines)

    --> Parse text
    local QueryResult = {}
    for Index, Line in Lines do
        --> Remove padding
        Line = string.gsub(Line, "\r", "")
        Line = string.sub(Line, 1, #Line - 1)

        if Component == "cpu" then
            table.insert(QueryResult, Line)
            continue
        end

        local SubResult = {}
        local LineResults = string.split(Line, " ")
        for Index, Result in LineResults do
            --> Ignore empty lines
            if string.gsub(Result, "%c", "") == "" then
                continue
            end

            table.insert(SubResult, Result)
        end

        table.insert(QueryResult, SubResult)
    end

    return QueryResult
end

local function WriteComputerSpecs()
    local Processor = QueryWMIC("cpu", "name")
    local MemorySticks = QueryWMIC("memorychip", "Capacity,Speed")
    
    Contents ..= `\n## Computer Specs`
    Contents ..= `\nProcessor: \`{Processor[1]}\`  `

    for Slot, Stick in MemorySticks do
        local Capacity = tonumber(Stick[1])
        Capacity //= 1e+9
        Contents ..= `\nMemory #{Slot}: \`{Capacity}GB {Stick[2]}\`  `
    end
end

type Benchmark = {
    Sent: number,
    Recieve: number,
    Bandwidth: {number},
    Framerate: {number}
}

local Metrics = {
    {
        Label = "FPS",
        Samples = "Framerate"
    },
    {
        Label = "Kbps",
        Samples = "Bandwidth"
    }
}

local function WriteBenchResults(Name: string, Results: {[string]: Benchmark})
    local Output = `\n## [{Name}](https://github.com/1Axen/Blink/blob/main/benchmark/src/shared/benches/{Name}.luau)\n`
   
    for Index, Metric in Metrics do
        if Index > 1 then
            Output ..= "\n\n"
        end

        Output ..= `|Tool ({Metric.Label})|Median|P0|P80|P90|P95|P100|Loss (%)|`
        Output ..= `\n|---|---|---|---|---|---|---|---|`
        for Tool, Result in Results do
            local Loss = math.floor((1 - (Result.Recieve / Result.Sent)) * 100)
            if Loss > 50 then
                Output ..= `\n|{Tool}|-|-|-|-|-|-|{Loss}%`
                continue
            end

            local Numbers = Result[Metric.Samples]
            local Formatted = table.create(#Numbers)
            for Index, Value in Numbers do
                Formatted[Index] = string.format("%.2f", Value)
            end

            Output ..= `\n|{Tool}|{table.concat(Formatted, "|")}|{Loss}%|`
        end
    end

    Contents ..= Output
end

--> Write computer specs
WriteComputerSpecs()

--> Sort tools alphabetically
local Array = {}
for Name, Benchmarks in Result do
    table.insert(Array, Name)
end

table.sort(Array, function(a, b)
    return #a < #b
end)

for _, Name in Array do
    WriteBenchResults(Name, Result[Name])
end

--> Output results
fs.writeFile("./Benchmarks.md", Contents)
print(`Success!`)