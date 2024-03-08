local Modes = require("../shared/modes")
local Benches = require("../shared/benches")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Stats = game:GetService("Stats")

type Benchmark = {
    Sent: number,
    Recieve: number,
    Bandwidth: {number},
    Framerate: {number}
}

type ToolResults = {
    [string]: Benchmark
}

local function Percentile(Samples: {number}, Percentile: number)
    assert((Percentile // 1) == Percentile and Percentile >= 0 and Percentile <= 100, "Percentile must be an integer between 0 and 100")
    local Index = ((#Samples * (Percentile / 100)) // 1)
    Index = math.max(Index, 1)
    return Samples[Index]
end

local function RunBenchmark(Tool: string, Bench: string): Benchmark
    local Total = 0
    local Frames = 0
    local Bandwidth = {}
    local Framerates = {}

    local Sent = 0
    local Data = Benches[Bench]
    local Events = Modes[Tool]

    local Event = Events[Bench]
    local Method;
    
    if Tool == "warp" then
        Method = function(Data)
            Event:Fire(true, Data)
        end
    elseif Tool == "roblox" then
        Method = function(Data)
            Event:FireServer(Data)
        end
    else
        Method = Event.Fire or Event.send
    end

    local Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
        Total += DeltaTime
        Frames += 1

        if Total >= 1 then
            Total -= 1
            table.insert(Bandwidth, Stats.DataSendKbps)
            table.insert(Framerates, Frames)
            Frames = 0
        end

        for Index = 1, 1000 do
            Sent += 1
            Method(Data)
        end
    end)

    task.wait(5)
    Connection:Disconnect()

    --> Generate results
    table.sort(Framerates)

    local FrameratePercentiles = {}
    local BandwidthPercentiles = {}

    for _, Percentage in {50, 0, 80, 90, 95, 100} do
        table.insert(BandwidthPercentiles, Percentile(Bandwidth, Percentage))
        table.insert(FrameratePercentiles, Percentile(Framerates, Percentage))
    end

    return {
        Sent = Sent,
        Recieve = 0,
        Bandwidth = BandwidthPercentiles,
        Framerate = FrameratePercentiles
    }
end

local function RunBenchmarks()
    local Results: {[string]: ToolResults} = {}
    for Tool in Modes do
        Results[Tool] = {}
        warn(`Running benchmarks with {Tool}...`)
        for Bench in Benches do
            print(`> Running {Bench}`)
            Results[Tool][Bench] = RunBenchmark(Tool, Bench)
            --> Give ROBLOX some time to rest in-between benchmarks
            task.wait(2)
        end

        --> Give ROBLOX some time to rest in-between tools
        task.wait(5)
    end

    local Recieved = ReplicatedStorage.Shared.GetRecieved:InvokeServer()
    for Tool, Benchmarks in Recieved do
        for Bench, Recieve in Benchmarks do
            Results[Tool][Bench].Recieve = Recieve
        end
    end

    print("Finished running benchmarks, generating results...")

    local OutputJSON = Instance.new("StringValue")
    OutputJSON.Name = "Result"
    OutputJSON.Value = HttpService:JSONEncode(Results)
    OutputJSON.Parent = game

    print("Generated results")
    print(OutputJSON)
    Selection:Set({OutputJSON})
end

RunBenchmarks()