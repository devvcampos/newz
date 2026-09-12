local LootESP = {}

function LootESP.Init(Config, Dependencies)
    local Workspace =
        game:GetService(
            "Workspace"
        )

    local Settings =
        Config.Loot
        or {}

    local Runtime =
        Config.Runtime
        or {}

    assert(
        type(Dependencies) == "table",
        "LootESP precisa de dependencias"
    )

    local Bounds = Dependencies.Bounds
    local Visuals = Dependencies.Visuals
    local SchedulerModule = Dependencies.SchedulerModule
    local Profiler = Dependencies.Profiler

    assert(
        Bounds
        and Visuals
        and SchedulerModule
        and type(SchedulerModule.New) == "function",
        "Dependencias invalidas em LootESP"
    )

    local ProfileBegin =
        Profiler
        and Profiler.Begin
        or function()
            return nil
        end

    local ProfileFinish =
        Profiler
        and Profiler.Finish
        or function()
        end

    local ProfileCount =
        Profiler
        and Profiler.Count
        or function()
        end

    local ProfileGauge =
        Profiler
        and Profiler.SetGauge
        or function()
        end

    local UpdateFrequency =
        math.clamp(
            tonumber(Runtime.UpdateFrequency) or 30,
            1,
            240
        )

    local Scheduler =
        SchedulerModule.New(
            UpdateFrequency
        )

    ---------------------------------------------------------
    -- HOT-PATH BINDINGS
    ---------------------------------------------------------

    local BoundsCreateState = Bounds.CreateState

    local VisualCreate = Visuals.Create
    local VisualHide = Visuals.Hide
    local VisualDestroyEntity = Visuals.DestroyEntity
    local VisualUpdateBox = Visuals.UpdateBox
    local VisualSetVisible = Visuals.SetVisible
    local VisualSetText = Visuals.SetText
    local VisualSetTextColor = Visuals.SetTextColor

    local SchedulerAdd = Scheduler.Add
    local SchedulerRemove = Scheduler.Remove
    local SchedulerStep = Scheduler.Step
    local SchedulerResetTiming = Scheduler.ResetTiming
    local SchedulerGetCount = Scheduler.GetCount
    local SchedulerDestroy = Scheduler.Destroy

    local Destroyed = false
    local WasEnabled = false

    local LootEntities = {}
    local Connections = {}

    local SelectionCandidates = {}
    local LastSelectionTime = 0
    local SelectedCount = 0

    ---------------------------------------------------------
    -- CATEGORY LOOKUP
    ---------------------------------------------------------

    local NameToCategory = {}

    local function RebuildNameLookup()
        table.clear(NameToCategory)

        local NamesMap = Settings.Names or {}

        for Category, Names in pairs(NamesMap) do
            if type(Names) == "table" then
                for _, Name in ipairs(Names) do
                    NameToCategory[Name] = Category
                end
            end
        end
    end

    RebuildNameLookup()

    local function GetLootCategory(Object)
        if
            not Object
            or (
                not Object:IsA("BasePart")
                and not Object:IsA("Model")
            )
        then
            return nil
        end

        -- Sobe na hierarquia procurando um nome que case com a categoria
        local Current = Object

        while Current do
            local Category = NameToCategory[Current.Name]

            if Category then
                if (Settings.Categories or {})[Category] == true then
                    return Category, Current
                end

                return nil
            end

            Current = Current.Parent

            if Current == Workspace then
                break
            end
        end

        return nil
    end

    ---------------------------------------------------------
    -- BOUNDS FOR GENERIC MODEL
    ---------------------------------------------------------

    local function GetObjectBounds(Data, Camera)
        local Object = Data.Loot

        if
            not Object
            or not Object.Parent
        then
            return nil
        end

        local State = Data.Bounds

        State.MinX = math.huge
        State.MinY = math.huge
        State.MaxX = -math.huge
        State.MaxY = -math.huge
        State.HasPoint = false

        local Checked = false

        local function ProjectPart(Part)
            if
                not Part
                or not Part:IsA("BasePart")
            then
                return
            end

            Checked = true

            local Size = Part.Size * 0.5
            local PartCFrame = Part.CFrame

            for X = -1, 1, 2 do
                for Y = -1, 1, 2 do
                    for Z = -1, 1, 2 do
                        local WorldPos =
                            PartCFrame:PointToWorldSpace(
                                Vector3.new(
                                    Size.X * X,
                                    Size.Y * Y,
                                    Size.Z * Z
                                )
                            )

                        local ScreenPos =
                            Camera:WorldToViewportPoint(
                                WorldPos
                            )

                        if ScreenPos.Z > 0.05 then
                            State.HasPoint = true

                            if ScreenPos.X < State.MinX then
                                State.MinX = ScreenPos.X
                            end

                            if ScreenPos.Y < State.MinY then
                                State.MinY = ScreenPos.Y
                            end

                            if ScreenPos.X > State.MaxX then
                                State.MaxX = ScreenPos.X
                            end

                            if ScreenPos.Y > State.MaxY then
                                State.MaxY = ScreenPos.Y
                            end
                        end
                    end
                end
            end
        end

        if Object:IsA("Model") then
            for _, Descendant in ipairs(Object:GetDescendants()) do
                if Descendant:IsA("BasePart") then
                    ProjectPart(Descendant)
                end
            end
        elseif Object:IsA("BasePart") then
            ProjectPart(Object)
        end

        if not Checked or not State.HasPoint then
            return nil
        end

        local Padding =
            tonumber(
                Settings.BoxPadding
            )
            or 2

        local X = State.MinX - Padding
        local Y = State.MinY - Padding

        local Width =
            (
                State.MaxX
                - State.MinX
            )
            + Padding * 2

        local Height =
            (
                State.MaxY
                - State.MinY
            )
            + Padding * 2

        if Width <= 2 or Height <= 2 then
            return nil
        end

        State.X = X
        State.Y = Y
        State.Width = Width
        State.Height = Height
        State.CenterX = X + Width / 2
        State.CenterY = Y + Height / 2

        return State
    end

    ---------------------------------------------------------
    -- HELPERS
    ---------------------------------------------------------

    local function DisconnectConnection(Connection)
        if Connection then
            pcall(
                Connection.Disconnect,
                Connection
            )
        end
    end

    local function HideLoot(Data)
        VisualHide(Data)
    end

    ---------------------------------------------------------
    -- LOOT LIFECYCLE
    ---------------------------------------------------------

    local function RegisterLoot(Object, Category)
        if
            Destroyed
            or not Object
            or LootEntities[Object]
        then
            return
        end

        local LootColor =
            (Settings.Colors or {})[Category]
            or Color3.fromRGB(
                120,
                220,
                255
            )

        local TextColor =
            Settings.TextColor
            or Color3.fromRGB(
                255,
                255,
                255
            )

        local Data = {
            Loot = Object,
            Category = Category,

            Bounds = BoundsCreateState(),
            RenderState = {},
            Hidden = false,

            Selected = false,
            SelectionDistanceSquared = math.huge,

            LastDistanceRounded = nil,
            DistanceText = "",
        }

        Data.Visuals =
            VisualCreate(
                "LOOT_" .. tostring(Object:GetDebugId()),
                {
                    "Name",
                    "Distance",
                },
                LootColor,
                TextColor
            )

        Data.Visuals.Labels.Name.Text =
            "["
            .. Category
            .. "] "
            .. Object.Name

        LootEntities[Object] = Data
        SchedulerAdd(Data)

        Data.Connections = {}

        Data.Connections.Removing =
            Object.AncestryChanged:Connect(function()
                if not Object:IsDescendantOf(Workspace) then
                    UnregisterLoot(Object)
                end
            end)

        VisualHide(Data)
    end

    function UnregisterLoot(Object)
        local Data =
            LootEntities[Object]

        if not Data then
            return
        end

        SchedulerRemove(Data)

        if Data.Connections then
            for _, Connection in pairs(Data.Connections) do
                DisconnectConnection(Connection)
            end

            table.clear(Data.Connections)
        end

        VisualDestroyEntity(Data)

        LootEntities[Object] = nil
    end

    ---------------------------------------------------------
    -- WORLD SCANNING
    ---------------------------------------------------------

    local function ScanWorld()
        if Destroyed then
            return
        end

        -- Primeira passada: registra tudo que já existe
        for _, Object in ipairs(Workspace:GetDescendants()) do
            if
                Object:IsA("BasePart")
                or Object:IsA("Model")
            then
                local Category = GetLootCategory(Object)

                if Category then
                    RegisterLoot(Object, Category)
                end
            end
        end
    end

    Connections.DescendantAdded =
        Workspace.DescendantAdded:Connect(function(Object)
            if
                Object:IsA("BasePart")
                or Object:IsA("Model")
            then
                local Category = GetLootCategory(Object)

                if Category then
                    RegisterLoot(Object, Category)
                end
            end
        end)

    ---------------------------------------------------------
    -- SELECTION
    ---------------------------------------------------------

    local function RefreshSelection(CameraPosition)
        local SelectionStart =
            ProfileBegin(
                "Loot.Selection"
            )

        table.clear(SelectionCandidates)

        local MaxDistance =
            tonumber(Settings.MaxDistance)
            or 500

        local MaxDistanceSquared =
            MaxDistance * MaxDistance

        for _, Data in pairs(LootEntities) do
            Data.Selected = false

            local Object = Data.Loot

            if Object and Object.Parent then
                local Pivot =
                    Object:IsA("Model")
                    and Object:GetPivot().Position
                    or Object.Position

                local Offset = Pivot - CameraPosition
                local DistanceSquared = Offset:Dot(Offset)

                if DistanceSquared <= MaxDistanceSquared then
                    Data.SelectionDistanceSquared =
                        DistanceSquared

                    SelectionCandidates[
                        #SelectionCandidates + 1
                    ] = Data
                end
            end
        end

        table.sort(
            SelectionCandidates,
            function(A, B)
                return
                    A.SelectionDistanceSquared
                    < B.SelectionDistanceSquared
            end
        )

        local MaxItems =
            math.clamp(
                math.floor(
                    tonumber(Settings.MaxItems) or 40
                ),
                1,
                200
            )

        local Limit =
            math.min(
                MaxItems,
                #SelectionCandidates
            )

        for Index = 1, Limit do
            SelectionCandidates[Index].Selected = true
        end

        SelectedCount = Limit

        for _, Data in pairs(LootEntities) do
            if not Data.Selected then
                VisualHide(Data)
            end
        end

        ProfileGauge(
            "LootSelected",
            SelectedCount
        )

        ProfileFinish(
            "Loot.Selection",
            SelectionStart
        )
    end

    ---------------------------------------------------------
    -- UPDATE
    ---------------------------------------------------------

    local function UpdateLoot(Data, Camera, CameraPosition)
        local Object = Data.Loot

        if not Object or not Object.Parent then
            HideLoot(Data)
            return
        end

        local Pivot =
            Object:IsA("Model")
            and Object:GetPivot().Position
            or Object.Position

        local Distance =
            (Pivot - CameraPosition).Magnitude

        local MaxDistance =
            tonumber(Settings.MaxDistance)
            or 500

        if Distance > MaxDistance then
            HideLoot(Data)
            return
        end

        local BoundsStart =
            ProfileBegin(
                "Loot.Bounds"
            )

        local LootBounds =
            GetObjectBounds(
                Data,
                Camera
            )

        ProfileFinish(
            "Loot.Bounds",
            BoundsStart
        )

        if not LootBounds then
            HideLoot(Data)
            return
        end

        local VisualStart =
            ProfileBegin(
                "Loot.Visuals"
            )

        local DistanceRounded =
            math.floor(Distance + 0.5)

        if
            Data.LastDistanceRounded
            ~= DistanceRounded
        then
            Data.LastDistanceRounded =
                DistanceRounded

            Data.DistanceText =
                tostring(DistanceRounded)
                .. " studs"
        end

        Data.Hidden = false

        local LootColor =
            (Settings.Colors or {})[Data.Category]
            or Color3.fromRGB(
                120,
                220,
                255
            )

        local TextColor =
            Settings.TextColor
            or Color3.fromRGB(
                255,
                255,
                255
            )

        VisualUpdateBox(
            Data,
            LootBounds,
            Settings,
            LootColor
        )

        local Labels = Data.Visuals.Labels
        local State = Data.RenderState

        VisualSetTextColor(
            State,
            "NameColor",
            Labels.Name,
            TextColor
        )

        VisualSetTextColor(
            State,
            "DistanceColor",
            Labels.Distance,
            TextColor
        )

        local ShowName =
            Settings.Name == true

        VisualSetVisible(
            State,
            "NameVisible",
            Labels.Name,
            ShowName
        )

        if ShowName then
            Labels.Name.Position =
                UDim2.fromOffset(
                    LootBounds.CenterX,
                    LootBounds.Y - 12
                )
        end

        local ShowDistance =
            Settings.Distance == true

        VisualSetVisible(
            State,
            "DistanceVisible",
            Labels.Distance,
            ShowDistance
        )

        if ShowDistance then
            VisualSetText(
                State,
                "DistanceText",
                Labels.Distance,
                Data.DistanceText
            )

            Labels.Distance.Position =
                UDim2.fromOffset(
                    LootBounds.CenterX,
                    LootBounds.Y
                    + LootBounds.Height
                    + 10
                )
        end

        ProfileFinish(
            "Loot.Visuals",
            VisualStart
        )
    end

    ---------------------------------------------------------
    -- SCHEDULED HOT PATH
    ---------------------------------------------------------

    local ActiveCamera = nil
    local ActiveCameraPosition = nil

    local function ProcessScheduledLoot(Data)
        if Data.Selected ~= true then
            return
        end

        local UpdateStart =
            ProfileBegin(
                "Loot.Update"
            )

        UpdateLoot(
            Data,
            ActiveCamera,
            ActiveCameraPosition
        )

        ProfileFinish(
            "Loot.Update",
            UpdateStart
        )

        ProfileCount(
            "LootUpdates",
            1
        )
    end

    ---------------------------------------------------------
    -- INITIAL SCAN
    ---------------------------------------------------------

    ScanWorld()

    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller = {}

    function Controller.Step(DeltaTime, Camera)
        if Destroyed then
            return 0
        end

        if Settings.Enabled ~= true then
            if WasEnabled then
                for _, Data in pairs(LootEntities) do
                    HideLoot(Data)
                    Data.Selected = false
                end

                SchedulerResetTiming()
                WasEnabled = false
            end

            LastSelectionTime = 0
            SelectedCount = 0
            ProfileGauge("LootSelected", 0)

            return 0
        end

        WasEnabled = true

        if not Camera then
            return 0
        end

        ActiveCamera = Camera
        ActiveCameraPosition = Camera.CFrame.Position

        local Now = os.clock()

        local SelectionInterval =
            math.clamp(
                tonumber(Settings.SelectionInterval)
                or 0.5,
                0.10,
                2
            )

        if
            LastSelectionTime == 0
            or Now - LastSelectionTime >= SelectionInterval
        then
            RefreshSelection(
                ActiveCameraPosition
            )

            LastSelectionTime = Now
        end

        local Budget =
            SchedulerStep(
                DeltaTime,
                ProcessScheduledLoot
            )

        ActiveCamera = nil
        ActiveCameraPosition = nil

        return Budget
    end

    function Controller.GetCount()
        return SchedulerGetCount()
    end

    function Controller.GetSelectedCount()
        return SelectedCount
    end

    function Controller.RebuildCategories()
        RebuildNameLookup()

        -- Reavalia tudo: itens que agora são válidos entram,
        -- itens que não são mais válidos saem
        for Object, Data in pairs(LootEntities) do
            local Category = GetLootCategory(Object)

            if not Category then
                UnregisterLoot(Object)
            else
                Data.Category = Category
            end
        end

        ScanWorld()
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        for _, Connection in pairs(Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Connections)

        for Object in pairs(LootEntities) do
            UnregisterLoot(Object)
        end

        table.clear(LootEntities)
        table.clear(SelectionCandidates)

        SchedulerDestroy()
    end

    return Controller
end

return LootESP