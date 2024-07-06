--!strict

---- Services ----

---- Imports ----

---- Settings ----

---- Constants ----

local Profiler = {}

--> Interface Instances
local Container: typeof(script.Parent.Widget) = script.Widget
local DebugContainer = Container.Debug
local MetricTemplate = DebugContainer.Metric:Clone()

type Profile = {
    Label: string,
    Metric: typeof(MetricTemplate),

    Tick: number,
    Time: number,

    Previous: Profile?,
    Children: {Profile},
}

---- Variables ----

local ActiveProfile: Profile?

---- Private Functions ----

local function formatPercentage(Percentage: number): string
    return `{math.floor(Percentage * 100)} %`
end

local function formatMilliseconds(Seconds: number): string
    return string.format("%.2f ms", Seconds * 1000)
end

local function updatePercentages(Time: number, Children: {Profile})
    for _, Profile in Children do
        Profile.Metric.Percentage.Text = formatPercentage(Profile.Time / Time)
        updatePercentages(Time, Profile.Children)
    end
end

---- Public Functions ----

function Profiler.profileBegin(Label: string)
    local Metric = DebugContainer:FindFirstChild(Label)
    if not Metric then
        local New = MetricTemplate:Clone()
        New.Name = Label
        New.Time.Text = "? ms"
        New.Label.Text = string.upper(Label)
        New.Parent = DebugContainer
        Metric = New
    end

    local Profile: Profile = {
        Label = Label,
        Metric = Metric,

        Tick = os.clock(),
        Time = 0,

        Children = {},
        Previous = ActiveProfile,
    }

    if ActiveProfile then
        table.insert(ActiveProfile.Children, Profile)
    end

    ActiveProfile = Profile
end

function Profiler.profileDiscard()
    assert(ActiveProfile ~= nil, "No active profile.")
    ActiveProfile = ActiveProfile.Previous
end

function Profiler.profileEnd()
    assert(ActiveProfile ~= nil, "No active profile.")
    local Elapsed = (os.clock() - ActiveProfile.Tick)

    ActiveProfile.Time = Elapsed
    ActiveProfile.Metric.Time.Text = formatMilliseconds(Elapsed)

    if not ActiveProfile.Previous then
        updatePercentages(Elapsed, ActiveProfile.Children) 
    end

    ActiveProfile = ActiveProfile.Previous
end

---- Initialization ----

function Profiler.Initialize()
    DebugContainer.Metric:Destroy()
    DebugContainer.Visible = true
end

---- Connections ----

return Profiler
