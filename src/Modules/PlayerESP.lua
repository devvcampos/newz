local PlayerESP = {}

function PlayerESP.Init(Config, Dependencies)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local Settings = Config.ESP
    local Runtime = Config.Runtime or {}

    assert(
        LocalPlayer,
        "PlayerESP precisa ser inicializado no cliente"
    )

    assert(
        type(Dependencies) == "table",
        "PlayerESP precisa de dependencias"
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
        "Dependencias invalidas em PlayerESP"
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

    local VisibilityInterval =
        math.max(
            0.01,
            tonumber(Runtime.VisibilityInterval) or 0.10
        )

    local Scheduler =
        SchedulerModule.New(
            UpdateFrequency
        )

    local Destroyed = false
    local WasEnabled = false

    local Entities = {}
    local PlayerConnections = {}
    local Connections = {}

    ---------------------------------------------------------
    -- VISIBILITY
    ---------------------------------------------------------

    local VisibilityParams = RaycastParams.new()
    VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
    VisibilityParams.IgnoreWater = true

    local VisibilityIgnore = {}

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

    ---------------------------------------------------------
    -- HUMANOID CACHE
    ---------------------------------------------------------

    local function BindHumanoid(Data, Humanoid)
        DisconnectConnection(
            Data.Connections.HumanoidHealth
        )

        DisconnectConnection(
            Data.Connections.HumanoidMaxHealth
        )

        Data.Connections.HumanoidHealth = nil
        Data.Connections.HumanoidMaxHealth = nil

        Data.Humanoid = Humanoid
        Data.HealthDirty = true

        if not Humanoid then
            return
        end

        Data.Connections.HumanoidHealth =
            Humanoid.HealthChanged:Connect(function()
                Data.HealthDirty = true
            end)

        Data.Connections.HumanoidMaxHealth =
            Humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
                Data.HealthDirty = true
            end)
    end

    ---------------------------------------------------------
    -- WEAPON TRACKING
    ---------------------------------------------------------

    local function IsEquippedWeapon(Object, Character)
        if
            not Object
            or Object.Parent ~= Character
            or not Object:IsA("Tool")
        then
            return false
        end

        return
            Object:GetAttribute("Type") == "Gun"
            or Object:GetAttribute("GunBound") == true
    end

    local function FindWeapon(Character)
        local SawTool = false

        for _, Object in ipairs(Character:GetChildren()) do
            if Object:IsA("Tool") then
                SawTool = true

                if IsEquippedWeapon(Object, Character) then
                    return Object, true
                end
            end
        end

        return nil, SawTool
    end

    local function RefreshWeapon(Data)
        if
            not Data
            or not Data.Character
            or not Data.Character.Parent
        then
            return
        end

        local Now = os.clock()
        local WeaponObject, SawTool =
            FindWeapon(Data.Character)

        Data.LastWeaponCheck = Now
        Data.WeaponObject = WeaponObject
        Data.WeaponName =
            WeaponObject
            and WeaponObject.Name
            or nil

        if WeaponObject then
            Data.WeaponProbeUntil = 0
        elseif SawTool then
            if (Data.WeaponProbeUntil or 0) <= 0 then
                Data.WeaponProbeUntil = Now + 2
            end
        else
            Data.WeaponProbeUntil = 0
        end
    end

    ---------------------------------------------------------
    -- HEALTH
    ---------------------------------------------------------

    local function UpdateHealthCache(Data, Humanoid, TextColor)
        local Dynamic =
            Settings.DynamicHealthColor == true

        local ColorNeedsRefresh =
            Data.HealthDirty
            or Data.LastDynamicHealth ~= Dynamic
            or (
                not Dynamic
                and Data.LastHealthTextColor ~= TextColor
            )

        if Data.HealthDirty then
            Data.HealthText =
                string.format(
                    "%d/%d HP",
                    math.floor(Humanoid.Health),
                    math.floor(Humanoid.MaxHealth)
                )
        end

        if ColorNeedsRefresh then
            if Dynamic then
                local MaxHealth =
                    math.max(
                        Humanoid.MaxHealth,
                        1
                    )

                local Ratio =
                    math.clamp(
                        Humanoid.Health / MaxHealth,
                        0,
                        1
                    )

                Data.HealthColor =
                    Color3.fromHSV(
                        Ratio * 0.33,
                        0.85,
                        1
                    )
            else
                Data.HealthColor = TextColor
            end
        end

        Data.LastDynamicHealth = Dynamic
        Data.LastHealthTextColor = TextColor
        Data.HealthDirty = false
    end

    ---------------------------------------------------------
    -- FILTERS
    ---------------------------------------------------------

    local function IsTeammate(Data)
        if not Settings.TeamCheck then
            return false
        end

        local Player = Data.Player

        if
            not Player
            or not LocalPlayer.Team
            or not Player.Team
        then
            return false
        end

        return Player.Team == LocalPlayer.Team
    end

    local function FindVisibilityTarget(Data, Root)
        local Target =
            Data.Head
            or Data.UpperTorso
            or Data.LowerTorso
            or Data.Torso
            or Root

        if
            Target
            and Target.Parent
            and Target:IsA("BasePart")
        then
            return Target
        end

        return Root
    end

    local function IsEntityVisible(Data, Camera, Root)
        if not Settings.VisibilityCheck then
            return true
        end

        local Now = os.clock()

        if
            Now - Data.LastVisibilityCheck
            < VisibilityInterval
        then
            return Data.LastVisibility
        end

        Data.LastVisibilityCheck = Now

        local Target =
            FindVisibilityTarget(
                Data,
                Root
            )

        if
            not Target
            or not Target:IsA("BasePart")
        then
            Data.LastVisibility = false
            return false
        end

        table.clear(VisibilityIgnore)
        VisibilityIgnore[1] = Camera

        if LocalPlayer.Character then
            VisibilityIgnore[2] = LocalPlayer.Character
        end

        VisibilityParams.FilterDescendantsInstances =
            VisibilityIgnore

        local Origin = Camera.CFrame.Position
        local Direction = Target.Position - Origin

        local Result =
            Workspace:Raycast(
                Origin,
                Direction,
                VisibilityParams
            )

        local Visible =
            not Result
            or (
                Result.Instance
                and Result.Instance:IsDescendantOf(
                    Data.Character
                )
            )

        Data.LastVisibility = Visible

        return Visible
    end

    ---------------------------------------------------------
    -- ENTITY LIFECYCLE
    ---------------------------------------------------------

    local function RegisterEntity(Player, Character)
        if Destroyed then
            return
        end

        if
            not Player
            or Player == LocalPlayer
            or not Character
            or not Character:IsA("Model")
            or Entities[Character]
        then
            return
        end

        local Root =
            Character:FindFirstChild(
                "HumanoidRootPart"
            )

        if
            Root
            and not Root:IsA("BasePart")
        then
            Root = nil
        end

        local VisibleColor =
            Settings.VisibleColor
            or Color3.fromRGB(
                90,
                255,
                130
            )

        local TextColor =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        local Data = {
            Player = Player,
            Character = Character,

            Root = Root,
            Humanoid = nil,

            Head = nil,
            UpperTorso = nil,
            LowerTorso = nil,
            Torso = nil,

            BodyParts = {},

            WeaponObject = nil,
            WeaponName = nil,
            LastWeaponCheck = 0,
            WeaponProbeUntil = 0,

            Connections = {},

            Bounds = Bounds.CreateState(),
            RenderState = {},
            Hidden = false,

            HealthDirty = true,
            HealthText = "",
            HealthColor = TextColor,
            LastDynamicHealth = nil,
            LastHealthTextColor = nil,

            LastDistanceRounded = nil,
            DistanceText = "",

            LastVisibilityCheck = 0,
            LastVisibility = false,
        }

        Data.Visuals =
            Visuals.Create(
                "ESP_" .. Player.Name,
                {
                    "Name",
                    "Health",
                    "Weapon",
                    "Distance",
                },
                VisibleColor,
                TextColor
            )

        Data.Visuals.Labels.Name.Text =
            Player.Name

        Entities[Character] = Data
        Scheduler.Add(Data)

        for _, Object in ipairs(Character:GetDescendants()) do
            Bounds.AddBodyPart(
                Data,
                Object
            )
        end

        BindHumanoid(
            Data,
            Character:FindFirstChildOfClass("Humanoid")
        )

        RefreshWeapon(Data)

        Data.Connections.DescendantAdded =
            Character.DescendantAdded:Connect(function(Object)
                Bounds.AddBodyPart(
                    Data,
                    Object
                )

                if
                    Object.Name == "HumanoidRootPart"
                    and Object:IsA("BasePart")
                then
                    Data.Root = Object

                elseif
                    Object:IsA("Humanoid")
                    and not Data.Humanoid
                then
                    BindHumanoid(
                        Data,
                        Object
                    )
                end
            end)

        Data.Connections.DescendantRemoving =
            Character.DescendantRemoving:Connect(function(Object)
                Bounds.RemoveBodyPart(
                    Data,
                    Object
                )

                if Data.Root == Object then
                    Data.Root = nil
                end

                if Data.Humanoid == Object then
                    BindHumanoid(
                        Data,
                        nil
                    )
                end
            end)

        Data.Connections.ChildAdded =
            Character.ChildAdded:Connect(function(Object)
                if Object:IsA("Tool") then
                    Data.WeaponProbeUntil =
                        os.clock() + 2

                    task.defer(
                        RefreshWeapon,
                        Data
                    )
                end
            end)

        Data.Connections.ChildRemoved =
            Character.ChildRemoved:Connect(function(Object)
                if
                    Object == Data.WeaponObject
                    or Object:IsA("Tool")
                then
                    task.defer(
                        RefreshWeapon,
                        Data
                    )
                end
            end)

        Visuals.Hide(Data)
    end

    local function UnregisterEntity(Character)
        local Data = Entities[Character]

        if not Data then
            return
        end

        Scheduler.Remove(Data)

        for _, Connection in pairs(Data.Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Data.Connections)

        Visuals.DestroyEntity(Data)

        Entities[Character] = nil
    end

    ---------------------------------------------------------
    -- PLAYER TRACKING
    ---------------------------------------------------------

    local function DisconnectPlayer(Player)
        local Set = PlayerConnections[Player]

        if Set then
            for _, Connection in pairs(Set) do
                DisconnectConnection(Connection)
            end

            PlayerConnections[Player] = nil
        end

        local RemoveQueue = {}

        for Character, Data in pairs(Entities) do
            if Data.Player == Player then
                RemoveQueue[#RemoveQueue + 1] = Character
            end
        end

        for _, Character in ipairs(RemoveQueue) do
            UnregisterEntity(Character)
        end
    end

    local function TrackPlayer(Player)
        if
            Destroyed
            or not Player
            or Player == LocalPlayer
            or PlayerConnections[Player]
        then
            return
        end

        local Set = {}
        PlayerConnections[Player] = Set

        Set.CharacterAdded =
            Player.CharacterAdded:Connect(function(Character)
                RegisterEntity(
                    Player,
                    Character
                )
            end)

        Set.CharacterRemoving =
            Player.CharacterRemoving:Connect(function(Character)
                UnregisterEntity(Character)
            end)

        if Player.Character then
            RegisterEntity(
                Player,
                Player.Character
            )
        end
    end

    ---------------------------------------------------------
    -- UPDATE
    ---------------------------------------------------------

    local function UpdateEntity(Data, Camera)
        local Player = Data.Player
        local Character = Data.Character

        if
            not Player
            or not Character
            or Player.Character ~= Character
            or not Character.Parent
        then
            Visuals.Hide(Data)
            return
        end

        if IsTeammate(Data) then
            Visuals.Hide(Data)
            return
        end

        local Root = Data.Root
        local Humanoid = Data.Humanoid

        if
            not Root
            or not Root.Parent
            or not Humanoid
            or not Humanoid.Parent
            or Humanoid.Health <= 0
        then
            Visuals.Hide(Data)
            return
        end

        local Now = os.clock()

        if
            not Data.WeaponObject
            and Data.WeaponProbeUntil > Now
            and Now - Data.LastWeaponCheck >= 0.25
        then
            RefreshWeapon(Data)
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
                "Players.Bounds"
            )

        local CharacterBounds =
            Bounds.GetCharacterBounds(
                Data,
                Camera,
                Root,
                Settings
            )

        ProfileFinish(
            "Players.Bounds",
            BoundsStart
        )

        if not CharacterBounds then
            Visuals.Hide(Data)
            return
        end

        local VisibilityStart =
            ProfileBegin(
                "Players.Visibility"
            )

        local Visible =
            IsEntityVisible(
                Data,
                Camera,
                Root
            )

        ProfileFinish(
            "Players.Visibility",
            VisibilityStart
        )

        local VisibleColor =
            Settings.VisibleColor
            or Color3.fromRGB(
                90,
                255,
                130
            )

        local HiddenColor =
            Settings.HiddenColor
            or Color3.fromRGB(
                255,
                90,
                90
            )

        local BoxColor = VisibleColor

        if
            Settings.VisibilityCheck
            and not Visible
        then
            BoxColor = HiddenColor
        end

        local TextColor =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        UpdateHealthCache(
            Data,
            Humanoid,
            TextColor
        )

        local VisualStart =
            ProfileBegin(
                "Players.Visuals"
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

        Visuals.UpdateBox(
            Data,
            CharacterBounds,
            Settings,
            BoxColor
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
            "WeaponColor",
            Labels.Weapon,
            TextColor
        )

        Visuals.SetTextColor(
            State,
            "DistanceColor",
            Labels.Distance,
            TextColor
        )

        Visuals.SetTextColor(
            State,
            "HealthColor",
            Labels.Health,
            Data.HealthColor
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

        local NextY =
            CharacterBounds.Y
            + CharacterBounds.Height
            + 10

        local ShowHealth =
            Settings.Health == true

        Visuals.SetVisible(
            State,
            "HealthVisible",
            Labels.Health,
            ShowHealth
        )

        if ShowHealth then
            Visuals.SetText(
                State,
                "HealthText",
                Labels.Health,
                Data.HealthText
            )

            Labels.Health.Position =
                UDim2.fromOffset(
                    CharacterBounds.CenterX,
                    NextY
                )

            NextY += 17
        end

        local WeaponName =
            Data.WeaponName

        local ShowWeapon =
            Settings.Weapon == true
            and type(WeaponName) == "string"
            and WeaponName ~= ""

        Visuals.SetVisible(
            State,
            "WeaponVisible",
            Labels.Weapon,
            ShowWeapon
        )

        if ShowWeapon then
            Visuals.SetText(
                State,
                "WeaponText",
                Labels.Weapon,
                WeaponName
            )

            Labels.Weapon.Position =
                UDim2.fromOffset(
                    CharacterBounds.CenterX,
                    NextY
                )

            NextY += 17
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
                    NextY
                )
        end

        ProfileFinish(
            "Players.Visuals",
            VisualStart
        )
    end

    ---------------------------------------------------------
    -- INITIAL TRACKING
    ---------------------------------------------------------

    for _, Player in ipairs(Players:GetPlayers()) do
        TrackPlayer(Player)
    end

    Connections.PlayerAdded =
        Players.PlayerAdded:Connect(function(Player)
            TrackPlayer(Player)
        end)

    Connections.PlayerRemoving =
        Players.PlayerRemoving:Connect(function(Player)
            DisconnectPlayer(Player)
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
                for _, Data in pairs(Entities) do
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
                            "Players.Update"
                        )

                    UpdateEntity(
                        Data,
                        Camera
                    )

                    ProfileFinish(
                        "Players.Update",
                        UpdateStart
                    )
                end
            )

        if Budget > 0 then
            ProfileCount(
                "PlayerUpdates",
                Budget
            )
        end

        return Budget
    end

    function Controller.Toggle(Value)
        Settings.Enabled =
            Value == true
    end

    function Controller.GetCount()
        return Scheduler.GetCount()
    end

    function Controller.GetLocalEntity()
        return LocalPlayer.Character
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

        local PlayerQueue = {}

        for Player in pairs(PlayerConnections) do
            PlayerQueue[#PlayerQueue + 1] = Player
        end

        for _, Player in ipairs(PlayerQueue) do
            DisconnectPlayer(Player)
        end

        table.clear(PlayerConnections)

        local EntityQueue = {}

        for Character in pairs(Entities) do
            EntityQueue[#EntityQueue + 1] = Character
        end

        for _, Character in ipairs(EntityQueue) do
            UnregisterEntity(Character)
        end

        table.clear(Entities)

        Scheduler.Destroy()
    end

    return Controller
end

return PlayerESP
