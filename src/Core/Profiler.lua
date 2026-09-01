local Profiler = {}

function Profiler.Init(Config)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Settings = Config.Profiler or {}

    assert(LocalPlayer, "Profiler precisa ser inicializado no cliente")

    local Destroyed = false
    local Metrics = {}
    local Counters = {}
    local Gauges = {}

    local Snapshot = {
        Timestamp = 0,
        FPS = 0,
        FrameAverageMs = 0,
        FramePeakMs = 0,
        Metrics = {},
        Counters = {},
        Gauges = {},
    }

    local WindowStart = os.clock()
    local WindowFrames = 0
    local WindowFrameTime = 0
    local WindowFramePeak = 0
    local LastEnabled = false

    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local OldGui = PlayerGui:FindFirstChild("newz_Profiler")

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "newz_Profiler"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 1001
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Enabled = false
    ScreenGui.Parent = PlayerGui

    local Panel = Instance.new("Frame")
    Panel.Name = "Panel"
    Panel.Position = UDim2.fromOffset(14, 48)
    Panel.Size = UDim2.fromOffset(430, 220)
    Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Panel.BackgroundTransparency = 0.15
    Panel.BorderSizePixel = 0
    Panel.Parent = ScreenGui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Panel

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(70, 70, 80)
    Stroke.Transparency = 0.25
    Stroke.Thickness = 1
    Stroke.Parent = Panel

    local Label = Instance.new("TextLabel")
    Label.Name = "Metrics"
    Label.Position = UDim2.fromOffset(10, 8)
    Label.Size = UDim2.new(1, -20, 1, -16)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Code
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(235, 235, 240)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Top
    Label.RichText = false
    Label.Text = "NEWZ PROFILER\nWaiting for samples..."
    Label.Parent = Panel

    local function ResetWindow(Now)
        table.clear(Metrics)
        table.clear(Counters)
        WindowStart = Now or os.clock()
        WindowFrames = 0
        WindowFrameTime = 0
        WindowFramePeak = 0
    end

    local function AddMetric(Name, Seconds)
        local Metric = Metrics[Name]
        if not Metric then
            Metric = {Sum = 0, Calls = 0, Peak = 0}
            Metrics[Name] = Metric
        end

        Metric.Sum += Seconds
        Metric.Calls += 1

        if Seconds > Metric.Peak then
            Metric.Peak = Seconds
        end
    end

    local function GetMetricSnapshot(Name)
        local Metric = Metrics[Name]
        if not Metric or Metric.Calls <= 0 then
            return {
                AverageMs = 0,
                PeakMs = 0,
                TotalMs = 0,
                Calls = 0,
            }
        end

        return {
            AverageMs = (Metric.Sum / Metric.Calls) * 1000,
            PeakMs = Metric.Peak * 1000,
            TotalMs = Metric.Sum * 1000,
            Calls = Metric.Calls,
        }
    end

    local function FormatMetric(Name, LabelName)
        local Metric = Snapshot.Metrics[Name]
        if not Metric then
            return string.format(
                "%-18s %7.3f ms  peak %7.3f",
                LabelName,
                0,
                0
            )
        end

        return string.format(
            "%-18s %7.3f ms  peak %7.3f",
            LabelName,
            Metric.AverageMs,
            Metric.PeakMs
        )
    end

    local function RefreshOverlay()
        local PlayersTracked = Snapshot.Gauges.PlayersTracked or 0
        local CorpsesTracked = Snapshot.Gauges.CorpsesTracked or 0
        local CorpsesSelected = Snapshot.Gauges.CorpsesSelected or 0
        local PlayerUpdates = Snapshot.Counters.PlayerUpdates or 0
        local CorpseUpdates = Snapshot.Counters.CorpseUpdates or 0
        local Render = Snapshot.Metrics["Newz.Render"]
        local RenderAverage = Render and Render.AverageMs or 0
        local FrameShare = 0

        if Snapshot.FrameAverageMs > 0 then
            FrameShare = (RenderAverage / Snapshot.FrameAverageMs) * 100
        end

        Label.Text = table.concat({
            string.format(
                "NEWZ PROFILER | v%s",
                tostring(Config.Project and Config.Project.Version or "?")
            ),
            string.format(
                "FPS %6.1f | frame %6.2f ms | peak %6.2f ms",
                Snapshot.FPS,
                Snapshot.FrameAverageMs,
                Snapshot.FramePeakMs
            ),
            string.format(
                "Newz %6.3f ms/frame | %5.1f%% frame",
                RenderAverage,
                FrameShare
            ),
            string.format(
                "Tracked: players %d | corpses %d | active %d",
                PlayersTracked,
                CorpsesTracked,
                CorpsesSelected
            ),
            string.format(
                "Updates/s: players %d | corpses %d",
                PlayerUpdates,
                CorpseUpdates
            ),
            FormatMetric("Projection.Setup", "Projection setup"),
            FormatMetric("Players.Update", "Player update"),
            FormatMetric("Players.Bounds", "Player bounds"),
            FormatMetric("Players.Visibility", "Visibility"),
            FormatMetric("Players.Visuals", "Player visuals"),
            FormatMetric("Corpses.Update", "Corpse update"),
            FormatMetric("Corpses.Bounds", "Corpse bounds"),
            FormatMetric("Corpses.Visuals", "Corpse visuals"),
            FormatMetric("Corpses.Selection", "Corpse select"),
        }, "\n")
    end

    local function FlushWindow(Now)
        local Elapsed = math.max(Now - WindowStart, 0.001)
        Snapshot.Timestamp = Now

        if WindowFrameTime > 0 then
            Snapshot.FPS = WindowFrames / WindowFrameTime
            Snapshot.FrameAverageMs =
                (WindowFrameTime / math.max(WindowFrames, 1)) * 1000
        else
            Snapshot.FPS = 0
            Snapshot.FrameAverageMs = 0
        end

        Snapshot.FramePeakMs = WindowFramePeak * 1000

        local MetricSnapshot = {}
        for Name in pairs(Metrics) do
            MetricSnapshot[Name] = GetMetricSnapshot(Name)
        end
        Snapshot.Metrics = MetricSnapshot

        local CounterSnapshot = {}
        for Name, Value in pairs(Counters) do
            CounterSnapshot[Name] =
                math.floor(Value / Elapsed + 0.5)
        end
        Snapshot.Counters = CounterSnapshot

        local GaugeSnapshot = {}
        for Name, Value in pairs(Gauges) do
            GaugeSnapshot[Name] = Value
        end
        Snapshot.Gauges = GaugeSnapshot

        if Settings.Overlay == true then
            ScreenGui.Enabled = true
            RefreshOverlay()
        else
            ScreenGui.Enabled = false
        end

        ResetWindow(Now)
    end

    local Controller = {}

    function Controller.Begin(Name)
        if Destroyed or Settings.Enabled ~= true then
            return nil
        end

        return os.clock()
    end

    function Controller.Finish(Name, StartTime)
        if
            Destroyed
            or Settings.Enabled ~= true
            or not StartTime
        then
            return
        end

        AddMetric(Name, os.clock() - StartTime)
    end

    function Controller.Add(Name, Seconds)
        if Destroyed or Settings.Enabled ~= true then
            return
        end

        AddMetric(Name, tonumber(Seconds) or 0)
    end

    function Controller.Count(Name, Amount)
        if Destroyed or Settings.Enabled ~= true then
            return
        end

        Counters[Name] =
            (Counters[Name] or 0)
            + (tonumber(Amount) or 1)
    end

    function Controller.SetGauge(Name, Value)
        if Destroyed then
            return
        end

        Gauges[Name] = Value
    end

    function Controller.Frame(DeltaTime)
        if Destroyed then
            return
        end

        local Enabled = Settings.Enabled == true

        if not Enabled then
            if LastEnabled then
                ResetWindow()
            end

            LastEnabled = false
            ScreenGui.Enabled = false
            return
        end

        if not LastEnabled then
            ResetWindow()
            LastEnabled = true
        end

        local DT = math.max(tonumber(DeltaTime) or 0, 0)
        WindowFrames += 1
        WindowFrameTime += DT

        if DT > WindowFramePeak then
            WindowFramePeak = DT
        end

        local Now = os.clock()
        local Interval =
            math.clamp(
                tonumber(Settings.ReportInterval) or 1,
                0.25,
                5
            )

        if Now - WindowStart >= Interval then
            FlushWindow(Now)
        elseif Settings.Overlay ~= true then
            ScreenGui.Enabled = false
        end
    end

    function Controller.GetSnapshot()
        return Snapshot
    end

    function Controller.Reset()
        ResetWindow()

        Snapshot.Timestamp = 0
        Snapshot.FPS = 0
        Snapshot.FrameAverageMs = 0
        Snapshot.FramePeakMs = 0
        Snapshot.Metrics = {}
        Snapshot.Counters = {}
        Snapshot.Gauges = {}

        Label.Text =
            "NEWZ PROFILER\nWaiting for samples..."
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        table.clear(Metrics)
        table.clear(Counters)
        table.clear(Gauges)

        if ScreenGui then
            pcall(ScreenGui.Destroy, ScreenGui)
        end
    end

    return Controller
end

return Profiler
