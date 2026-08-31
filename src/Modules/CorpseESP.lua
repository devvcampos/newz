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
    local LootModule = Dependencies.LootModule
    local Profiler = Dependencies.Profiler

    assert(
        Bounds
        and Visuals
        and SchedulerModule
        and type(SchedulerModule.New) == "function"
        and LootModule
        and type(LootModule.New) == "function",
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

    local Loot =
        LootModule.New(
            Config,
            {
                Profiler = Profiler,
            }
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

    local LootPrepare = Loot.Prepare
    local LootSync = Loot.Sync
    local LootSuspend = Loot.Suspend
    local LootDestroyData = Loot.DestroyData

    local Destroyed = false
    local WasEnabled = false

    local CorpseEntities = {}
    local CorpseFolder = nil
    local CorpseFolderConnections = {}
    local Connections = {}

    local function DisconnectConnection(Connection)
        if Connection then
            pcall(
                Connection.Disconnect,
                Connection
            )
        end
    end

    local function HideCorpse(Data)
        VisualHide(
            Data
        )

        LootSuspend(
            Data
        )
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

            LastDistanceRounded = nil,
            DistanceText = "",
        }

        Data.Visuals =
            VisualCreate(
                "CORPSE_" .. Corpse.Name,
                {
                    "Name",
                    "Distance",
                    "Loot",
                },
                CorpseColor,
                TextColor
            )

        Data.Visuals.Labels.Name.Text =
            "[CORPSE] "
            .. Corpse.Name

        local LootLabel =
            Data.Visuals.Labels.Loot

        LootLabel.AnchorPoint =
            Vector2.new(
                0.5,
                0
            )

        LootLabel.TextYAlignment =
            Enum.TextYAlignment.Top

        LootLabel.Size =
            UDim2.fromOffset(
                280,
                18
            )

        LootPrepare(
            Data,
            Corpse
        )

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

        LootDestroyData(
            Data
        )

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
            or 1000

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

        local LootText = ""
        local LootLineCount = 0

        if
            Settings.Loot == true
            or (
                Data.Loot
                and Data.Loot.Active
            )
        then
            LootText,
                LootLineCount =
                    LootSync(
                        Data
                    )
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

        VisualSetTextColor(
            State,
            "LootColor",
            Labels.Loot,
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

        local NextY =
            CharacterBounds.Y
            + CharacterBounds.Height
            + 10

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
                    NextY
                )

            NextY += 17
        end

        local ShowLoot =
            Settings.Loot == true
            and LootText ~= ""

        VisualSetVisible(
            State,
            "LootVisible",
            Labels.Loot,
            ShowLoot
        )

        if ShowLoot then
            VisualSetText(
                State,
                "LootText",
                Labels.Loot,
                LootText
            )

            local LootHeight =
                math.max(
                    18,
                    LootLineCount * 16
                )

            if
                State.LootHeight
                ~= LootHeight
            then
                Labels.Loot.Size =
                    UDim2.fromOffset(
                        280,
                        LootHeight
                    )

                State.LootHeight =
                    LootHeight
            end

            Labels.Loot.Position =
                UDim2.fromOffset(
                    CharacterBounds.CenterX,
                    NextY
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
                end

                SchedulerResetTiming()
                WasEnabled = false
            end

            return 0
        end

        WasEnabled = true

        if not Camera then
            return 0
        end

        ActiveCamera =
            Camera

        ActiveCameraPosition =
            Camera.CFrame.Position

        local Budget =
            SchedulerStep(
                DeltaTime,
                ProcessScheduledCorpse
            )

        ActiveCamera = nil
        ActiveCameraPosition = nil

        if Budget > 0 then
            ProfileCount(
                "CorpseUpdates",
                Budget
            )
        end

        return Budget
    end

    function Controller.GetCount()
        return SchedulerGetCount()
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

        SchedulerDestroy()
    end

    return Controller
end

return CorpseESP
