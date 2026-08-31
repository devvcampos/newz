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
                Bounds.FindCorpseRoot(
                    Corpse
                ),

            Head = nil,
            UpperTorso = nil,
            LowerTorso = nil,
            Torso = nil,

            BodyParts = {},
            Connections = {},

            Bounds = Bounds.CreateState(),
            RenderState = {},
            Hidden = false,

            LastDistanceRounded = nil,
            DistanceText = "",
        }

        Data.Visuals =
            Visuals.Create(
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
        Scheduler.Add(Data)

        for _, Object in ipairs(Corpse:GetDescendants()) do
            Bounds.AddBodyPart(
                Data,
                Object
            )
        end

        Data.Connections.DescendantAdded =
            Corpse.DescendantAdded:Connect(function(Object)
                Bounds.AddBodyPart(
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
                        Bounds.FindCorpseRoot(
                            Corpse
                        )
                end
            end)

        Data.Connections.DescendantRemoving =
            Corpse.DescendantRemoving:Connect(function(Object)
                Bounds.RemoveBodyPart(
                    Data,
                    Object
                )

                if Data.Root == Object then
                    Data.Root = nil

                    task.defer(function()
                        if Corpse.Parent then
                            Data.Root =
                                Bounds.FindCorpseRoot(
                                    Corpse
                                )
                        end
                    end)
                end
            end)

        Visuals.Hide(Data)
    end

    local function UnregisterCorpse(Corpse)
        local Data =
            CorpseEntities[Corpse]

        if not Data then
            return
        end

        Scheduler.Remove(Data)

        for _, Connection in pairs(Data.Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Data.Connections)

        Visuals.DestroyEntity(Data)

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

    local function UpdateCorpse(Data, Camera)
        local Corpse = Data.Corpse

        if
            not Corpse
            or not Corpse.Parent
            or (
                CorpseFolder
                and Corpse.Parent ~= CorpseFolder
            )
        then
            Visuals.Hide(Data)
            return
        end

        local Root = Data.Root

        if
            not Root
            or not Root.Parent
        then
            Root =
                Bounds.FindCorpseRoot(
                    Corpse
                )

            Data.Root = Root
        end

        if not Root then
            Visuals.Hide(Data)
            return
        end

        local Distance =
            (
                Root.Position
                - Camera.CFrame.Position
            ).Magnitude

        local MaxDistance =
            tonumber(Settings.MaxDistance)
            or 1000

        if Distance > MaxDistance then
            Visuals.Hide(Data)
            return
        end

        local BoundsStart =
            ProfileBegin(
                "Corpses.Bounds"
            )

        local CharacterBounds =
            Bounds.GetCharacterBounds(
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
            Visuals.Hide(Data)
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

        Visuals.UpdateBox(
            Data,
            CharacterBounds,
            Settings,
            CorpseColor
        )

        local Labels = Data.Visuals.Labels
        local State = Data.RenderState

        Visuals.SetTextColor(
            State,
            "NameColor",
            Labels.Name,
            TextColor
        )

        Visuals.SetTextColor(
            State,
            "DistanceColor",
            Labels.Distance,
            TextColor
        )

        local ShowName =
            Settings.Name == true

        Visuals.SetVisible(
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

        Visuals.SetVisible(
            State,
            "DistanceVisible",
            Labels.Distance,
            ShowDistance
        )

        if ShowDistance then
            Visuals.SetText(
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
                    Visuals.Hide(Data)
                end

                Scheduler.ResetTiming()
                WasEnabled = false
            end

            return 0
        end

        WasEnabled = true

        if not Camera then
            return 0
        end

        local Budget =
            Scheduler.Step(
                DeltaTime,
                function(Data)
                    local UpdateStart =
                        ProfileBegin(
                            "Corpses.Update"
                        )

                    UpdateCorpse(
                        Data,
                        Camera
                    )

                    ProfileFinish(
                        "Corpses.Update",
                        UpdateStart
                    )
                end
            )

        if Budget > 0 then
            ProfileCount(
                "CorpseUpdates",
                Budget
            )
        end

        return Budget
    end

    function Controller.GetCount()
        return Scheduler.GetCount()
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

        Scheduler.Destroy()
    end

    return Controller
end

return CorpseESP
