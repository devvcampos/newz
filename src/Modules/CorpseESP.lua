local CorpseESP = {}

function CorpseESP.Init(Config, Dependencies)
    local Workspace =
        game:GetService(
            "Workspace"
        )

    local Settings =
        Config.Corpses
        or {}

    local Runtime =
        Config.Runtime
        or {}

    assert(
        type(Dependencies) == "table",
        "CorpseESP precisa de dependencias"
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
        "Dependencias invalidas em CorpseESP"
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
    local BoundsAddBodyPart = Bounds.AddBodyPart
    local BoundsRemoveBodyPart = Bounds.RemoveBodyPart
    local BoundsFindCorpseRoot = Bounds.FindCorpseRoot
    local BoundsGetCharacterBounds = Bounds.GetCharacterBounds

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

    local CorpseEntities = {}
    local CorpseFolder = nil
    local CorpseFolderConnections = {}
    local Connections = {}

    -- Reused list to avoid allocating a fresh candidate array every refresh.
    local SelectionCandidates = {}
    local LastSelectionTime = 0
    local SelectedCount = 0

    local function DisconnectConnection(Connection)
        if Connection then
            pcall(
                Connection.Disconnect,
                Connection
            )
        end
    end

    local function HideCorpse(Data)
        VisualHide(Data)
    end

    ---------------------------------------------------------
    -- CORPSE LIFECYCLE
    ---------------------------------------------------------

    local function RegisterCorpse(Corpse)
        if
            Destroyed
            or not Corpse
            or not Corpse:IsA("Model")
            or CorpseEntities[Corpse]
        then
            return
        end

        local CorpseColor =
            Settings.Color
            or Color3.fromRGB(
                255,
                190,
                90
            )

        local TextColor =
            Settings.TextColor
            or Color3.fromRGB(
                255,
                255,
                255
            )

        local Data = {
            Character = Corpse,
            Corpse = Corpse,

            Root =
                BoundsFindCorpseRoot(
                    Corpse
                ),

            Head = nil,
            UpperTorso = nil,
            LowerTorso = nil,
            Torso = nil,

            BodyParts = {},
            Connections = {},

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
                "CORPSE_" .. Corpse.Name,
                {
                    "Name",
                    "Distance",
                },
                CorpseColor,
                TextColor
            )

        Data.Visuals.Labels.Name.Text =
            "[CORPSE] "
            .. Corpse.Name

        CorpseEntities[Corpse] = Data
        SchedulerAdd(Data)

        for _, Object in ipairs(Corpse:GetDescendants()) do
            BoundsAddBodyPart(
                Data,
                Object
            )
        end

        Data.Connections.DescendantAdded =
            Corpse.DescendantAdded:Connect(function(Object)
                BoundsAddBodyPart(
                    Data,
                    Object
                )

                if
                    Object.Name == "HumanoidRootPart"
                    and Object:IsA("BasePart")
                then
                    Data.Root = Object
                elseif not Data.Root then
                    Data.Root =
                        BoundsFindCorpseRoot(
                            Corpse
                        )
                end
            end)

        Data.Connections.DescendantRemoving =
            Corpse.DescendantRemoving:Connect(function(Object)
                BoundsRemoveBodyPart(
                    Data,
                    Object
                )

                if Data.Root == Object then
                    Data.Root = nil

                    task.defer(function()
                        if Corpse.Parent then
                            Data.Root =
                                BoundsFindCorpseRoot(
                                    Corpse
                                )
                        end
                    end)
                end
            end)

        VisualHide(Data)
    end

    local function UnregisterCorpse(Corpse)
        local Data =
            CorpseEntities[Corpse]

        if not Data then
            return
        end

        SchedulerRemove(Data)

        for _, Connection in pairs(Data.Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Data.Connections)

        VisualDestroyEntity(Data)

        CorpseEntities[Corpse] = nil
    end

    ---------------------------------------------------------
    -- FOLDER TRACKING
    ---------------------------------------------------------

    local function DisconnectCorpseFolder()
        for _, Connection
            in pairs(
                CorpseFolderConnections
            )
        do
            DisconnectConnection(Connection)
        end

        table.clear(CorpseFolderConnections)

        local RemoveQueue = {}

        for Corpse in pairs(CorpseEntities) do
            RemoveQueue[#RemoveQueue + 1] = Corpse
        end

        for _, Corpse in ipairs(RemoveQueue) do
            UnregisterCorpse(Corpse)
        end

        table.clear(SelectionCandidates)
        SelectedCount = 0
        LastSelectionTime = 0
        ProfileGauge("CorpsesSelected", 0)

        CorpseFolder = nil
    end

    local function BindCorpseFolder(Folder)
        if
            Destroyed
            or not Folder
            or CorpseFolder == Folder
        then
            return
        end

        DisconnectCorpseFolder()

        CorpseFolder = Folder

        for _, Object in ipairs(Folder:GetChildren()) do
            if Object:IsA("Model") then
                RegisterCorpse(Object)
            end
        end

        CorpseFolderConnections.ChildAdded =
            Folder.ChildAdded:Connect(function(Object)
                if Object:IsA("Model") then
                    RegisterCorpse(Object)
                end
            end)

        CorpseFolderConnections.ChildRemoved =
            Folder.ChildRemoved:Connect(function(Object)
                UnregisterCorpse(Object)
            end)
    end

    ---------------------------------------------------------
    -- ACTIVE CORPSE SELECTION
    ---------------------------------------------------------

    local function RefreshSelection(CameraPosition)
        local SelectionStart =
            ProfileBegin(
                "Corpses.Selection"
            )

        table.clear(SelectionCandidates)

        local MaxDistance =
            tonumber(Settings.MaxDistance)
            or 500

        local MaxDistanceSquared =
            MaxDistance * MaxDistance

        for _, Data in pairs(CorpseEntities) do
            Data.Selected = false

            local Corpse = Data.Corpse

            if
                Corpse
                and Corpse.Parent
                and (
                    not CorpseFolder
                    or Corpse.Parent == CorpseFolder
                )
            then
                local Root = Data.Root

                if
                    not Root
                    or not Root.Parent
                then
                    Root =
                        BoundsFindCorpseRoot(
                            Corpse
                        )

                    Data.Root = Root
                end

                if Root then
                    local Offset =
                        Root.Position
                        - CameraPosition

                    local DistanceSquared =
                        Offset:Dot(Offset)

                    if
                        DistanceSquared
                        <= MaxDistanceSquared
                    then
                        Data.SelectionDistanceSquared =
                            DistanceSquared

                        SelectionCandidates[
                            #SelectionCandidates + 1
                        ] = Data
                    end
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

        local MaxCorpses =
            math.clamp(
                math.floor(
                    tonumber(Settings.MaxCorpses)
                    or 8
                ),
                1,
                100
            )

        local Limit =
            math.min(
                MaxCorpses,
                #SelectionCandidates
            )

        for Index = 1, Limit do
            SelectionCandidates[Index].Selected = true
        end

        SelectedCount = Limit

        -- Anything outside the active set disappears immediately.
        for _, Data in pairs(CorpseEntities) do
            if not Data.Selected then
                VisualHide(Data)
            end
        end

        ProfileGauge(
            "CorpsesSelected",
            SelectedCount
        )

        ProfileFinish(
            "Corpses.Selection",
            SelectionStart
        )
    end

    ---------------------------------------------------------
    -- UPDATE
    ---------------------------------------------------------

    local function UpdateCorpse(
        Data,
        Camera,
        CameraPosition
    )
        local Corpse = Data.Corpse

        if
            not Corpse
            or not Corpse.Parent
            or (
                CorpseFolder
                and Corpse.Parent ~= CorpseFolder
            )
        then
            HideCorpse(Data)
            return
        end

        local Root = Data.Root

        if
            not Root
            or not Root.Parent
        then
            Root =
                BoundsFindCorpseRoot(
                    Corpse
                )

            Data.Root = Root
        end

        if not Root then
            HideCorpse(Data)
            return
        end

        local Distance =
            (
                Root.Position
                - CameraPosition
            ).Magnitude

        local MaxDistance =
            tonumber(Settings.MaxDistance)
            or 500

        if Distance > MaxDistance then
            HideCorpse(Data)
            return
        end

        local BoundsStart =
            ProfileBegin(
                "Corpses.Bounds"
            )

        local CharacterBounds =
            BoundsGetCharacterBounds(
                Data,
                Camera,
                Root,
                Settings
            )

        ProfileFinish(
            "Corpses.Bounds",
            BoundsStart
        )

        if not CharacterBounds then
            HideCorpse(Data)
            return
        end

        local VisualStart =
            ProfileBegin(
                "Corpses.Visuals"
            )

        local DistanceRounded =
            math.floor(
                Distance + 0.5
            )

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

        local CorpseColor =
            Settings.Color
            or Color3.fromRGB(
                255,
                190,
                90
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
            CharacterBounds,
            Settings,
            CorpseColor
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
                    CharacterBounds.CenterX,
                    CharacterBounds.Y - 12
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
                    CharacterBounds.CenterX,
                    CharacterBounds.Y
                    + CharacterBounds.Height
                    + 10
                )
        end

        ProfileFinish(
            "Corpses.Visuals",
            VisualStart
        )
    end

    ---------------------------------------------------------
    -- INITIAL FOLDER BINDING
    ---------------------------------------------------------

    local CorpseFolderName =
        tostring(
            Settings.FolderName
            or "Corpses"
        )

    local ExistingCorpseFolder =
        Workspace:FindFirstChild(
            CorpseFolderName
        )

    if ExistingCorpseFolder then
        BindCorpseFolder(
            ExistingCorpseFolder
        )
    end

    Connections.CorpseFolderAdded =
        Workspace.ChildAdded:Connect(function(Object)
            if Object.Name == CorpseFolderName then
                BindCorpseFolder(Object)
            end
        end)

    Connections.CorpseFolderRemoved =
        Workspace.ChildRemoved:Connect(function(Object)
            if Object == CorpseFolder then
                DisconnectCorpseFolder()
            end
        end)

    ---------------------------------------------------------
    -- SCHEDULED HOT PATH
    ---------------------------------------------------------

    local ActiveCamera = nil
    local ActiveCameraPosition = nil

    local function ProcessScheduledCorpse(Data)
        if Data.Selected ~= true then
            return
        end

        local UpdateStart =
            ProfileBegin(
                "Corpses.Update"
            )

        UpdateCorpse(
            Data,
            ActiveCamera,
            ActiveCameraPosition
        )

        ProfileFinish(
            "Corpses.Update",
            UpdateStart
        )

        ProfileCount(
            "CorpseUpdates",
            1
        )
    end

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
                for _, Data in pairs(CorpseEntities) do
                    HideCorpse(Data)
                    Data.Selected = false
                end

                SchedulerResetTiming()
                WasEnabled = false
            end

            LastSelectionTime = 0
            SelectedCount = 0
            ProfileGauge("CorpsesSelected", 0)

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
                or 0.25,
                0.10,
                2
            )

        if
            LastSelectionTime == 0
            or Now - LastSelectionTime
                >= SelectionInterval
        then
            RefreshSelection(
                ActiveCameraPosition
            )

            LastSelectionTime = Now
        end

        local Budget =
            SchedulerStep(
                DeltaTime,
                ProcessScheduledCorpse
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

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        for _, Connection in pairs(Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Connections)

        DisconnectCorpseFolder()
        table.clear(CorpseEntities)
        table.clear(SelectionCandidates)

        SchedulerDestroy()
    end

    return Controller
end

return CorpseESP
