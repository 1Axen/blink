local Modes = require("../shared/modes")
local Benches = require("../shared/benches")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")

local MAXIMUM_FRAMERATE = 60

local Camera = workspace.CurrentCamera
Camera.FieldOfView = 1
Camera.CFrame = CFrame.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

Players.LocalPlayer.PlayerGui:ClearAllChildren()
Players.LocalPlayer.PlayerScripts:ClearAllChildren()

for _, Item in Enum.CoreGuiType:GetEnumItems() do
    while true do
        local Success = pcall(function()
            StarterGui:SetCoreGuiEnabled(Item, false)
        end)

        if Success then
            break
        end
    end
end

type Benchmark = {
    Sent: number,
    Receive: number,
    Bandwidth: {number},
    Framerate: {number}
}

type Results = {
    [string]: {
        [string]: Benchmark
    }
}

local function Percentile(Samples: {number}, Percentile: number)
    assert((Percentile // 1) == Percentile and Percentile >= 0 and Percentile <= 100, "Percentile must be an integer between 0 and 100")
    local Index = ((#Samples * (Percentile / 100)) // 1)
    Index = math.max(Index, 1)
    return Samples[Index]
end

local function WaitForPacketsToProcess()
    print("Waiting for packets to be processed.")
    while (Stats.DataSendKbps > 0.5) do
        RunService.Heartbeat:Wait()
    end

    task.wait(5)
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
            local Scale = (MAXIMUM_FRAMERATE / Frames)
            table.insert(Bandwidth, Stats.DataSendKbps * Scale)
            table.insert(Framerates, Frames)
            Frames = 0
        end

        for Index = 1, 1000 do
            Sent += 1
            Method(Data)
        end
    end)

    task.wait(10)
    Connection:Disconnect()
    print(`> Finished running with {Tool}`)

    --> Generate results
    table.sort(Bandwidth)
    table.sort(Framerates, function(a, b)
        return a > b
    end)

    local FrameratePercentiles = {}
    local BandwidthPercentiles = {}

    for _, Percentage in {50, 0, 80, 90, 95, 100} do
        table.insert(BandwidthPercentiles, Percentile(Bandwidth, Percentage))
        table.insert(FrameratePercentiles, Percentile(Framerates, Percentage))
    end

    return {
        Sent = Sent,
        Receive = 0,
        Bandwidth = BandwidthPercentiles,
        Framerate = FrameratePercentiles
    }
end

local function RunBenchmarks()
    local Results: Results = {}
    for Bench in Benches do
        warn(`Running {Bench} benchmark`)
        Results[Bench] = {}

        for Tool in Modes do
            print(`> Running with {Tool}`)
            Results[Bench][Tool] = RunBenchmark(Tool, Bench)
    
            --> Give ROBLOX some time to rest in-between tools
            WaitForPacketsToProcess()
        end

        --> Give ROBLOX some time to rest in-between benchmarks
        WaitForPacketsToProcess()
    end
    
    local Received = ReplicatedStorage.Shared.GetReceived:InvokeServer()
    for Bench, Tools in Received do
        for Tool, Receive in Tools do
            Results[Bench][Tool].Receive = Receive
        end
    end

    print("Finished running benchmarks, generating results...")
    ReplicatedStorage.Shared.Generate:FireServer(HttpService:JSONEncode(Results))
end

RunBenchmarks()