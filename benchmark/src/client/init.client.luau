local Zap = require(game.ReplicatedStorage.zap.Client)
local Blink = require(game.ReplicatedStorage.blink.Client)
local Benches = require(game.ReplicatedStorage.benches)

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

type BenchmarkResults = {
    Framerate: number,
    Bandwidth: number
}

local function Average(Samples: {number}): number
    local Sum = 0
    for _, Value in Samples do
        Sum += Value
    end
    return Sum / #Samples
end

local function RunBenchmark(Tool: "Zap" | "Blink", Bench: string): BenchmarkResults
    local Total = 0
    local Frames = 0

    local Sends = {}
    local Framerates = {}

    local Data = Benches[Bench]
    local Method = Tool == "Blink" and Blink.Fire or Zap.Fire
    local Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
        Total += DeltaTime
        Frames += 1
        table.insert(Sends, Stats.DataSendKbps)

        if Total >= 1 then
            Total -= 1
            table.insert(Framerates, Frames)
            Frames = 0
        end

        Method(Data)
    end)

    task.wait(5)

    return {
        Framerate = Average(Framerates),
        Bandwidth = Average(Sends)
    }
end

print("Blink", RunBenchmark("Blink", "Booleans"))
task.wait(2)

print("Zap", RunBenchmark("Blink", "Booleans"))
