local ESP = {}

function ESP.Init(Config, Dependencies)
    ---------------------------------------------------------
    -- SERVICES / CONFIG
    ---------------------------------------------------------

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local Settings = Config.ESP
    local CorpseSettings = Config.Corpses or {}
    local Runtime = Config.Runtime or {}

    local Profiler =
        Dependencies
        and Dependencies.Profiler
        or nil

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

    local ProfileFrame =
        Profiler
        and Profiler.Frame
        or function()
        end

    assert(LocalPlayer, "ESP precisa ser inicializado no cliente")

    ---------------------------------------------------------
    -- STATE
    ---------------------------------------------------------

    local Destroyed = false

    -- Lookup by Character.
    local Entities = {}

    -- Dense list used by the round-robin scheduler.
    local EntityList = {}

    local Connections = {}
    local PlayerConnections = {}

    -- Corpse lookup/list. Corpses are independent from Player.Character.
    local CorpseEntities = {}
    local CorpseList = {}
    local CorpseFolder = nil
    local CorpseFolderConnections = {}

    ---------------------------------------------------------
    -- PERFORMANCE
    ---------------------------------------------------------

    local UpdateFrequency =
        math.clamp(
            tonumber(Runtime.UpdateFrequency) or 30,
            1,
            240
        )

    local VISIBILITY_INTERVAL =
        math.max(
            0.01,
            tonumber(Runtime.VisibilityInterval) or 0.10
        )

    -- Work is spread across rendered frames while preserving the
    -- configured average update frequency per entity.
    local SchedulerCursor = 1
    local SchedulerAccumulator = 0
    local WasEnabled = false

    local CorpseSchedulerCursor = 1
    local CorpseSchedulerAccumulator = 0
    local WasCorpsesEnabled = false

    ---------------------------------------------------------
    -- VISIBILITY
    ---------------------------------------------------------

    local VisibilityParams = RaycastParams.new()
    VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
    VisibilityParams.IgnoreWater = true

    -- Reused so visibility checks do not allocate a fresh table.
    local VisibilityIgnore = {}

    ---------------------------------------------------------
    -- BODY PARTS
    ---------------------------------------------------------

    local BodyPartNames = {
        -- R6
        ["Head"] = true,
        ["Head2"] = true,
        ["Torso"] = true,
        ["Left Arm"] = true,
        ["Right Arm"] = true,
        ["Left Leg"] = true,
        ["Right Leg"] = true,

        -- R15
        ["UpperTorso"] = true,
        ["LowerTorso"] = true,
        ["LeftUpperArm"] = true,
        ["LeftLowerArm"] = true,
        ["LeftHand"] = true,
        ["RightUpperArm"] = true,
        ["RightLowerArm"] = true,
        ["RightHand"] = true,
        ["LeftUpperLeg"] = true,
        ["LeftLowerLeg"] = true,
        ["LeftFoot"] = true,
        ["RightUpperLeg"] = true,
        ["RightLowerLeg"] = true,
        ["RightFoot"] = true,
    }

    ---------------------------------------------------------
    -- GUI
    ---------------------------------------------------------

    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local OldGui = PlayerGui:FindFirstChild("newz_ESP")

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "newz_ESP"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui

    ---------------------------------------------------------
    -- VISUAL HELPERS
    ---------------------------------------------------------

    local function CreateText()
        local Text = Instance.new("TextLabel")
        Text.BackgroundTransparency = 1
        Text.Size = UDim2.fromOffset(220, 18)
        Text.AnchorPoint = Vector2.new(0.5, 0.5)
        Text.Font = Enum.Font.Gotham
        Text.TextSize = 13
        Text.TextColor3 = Settings.TextColor or Color3.new(1, 1, 1)
        Text.TextStrokeColor3 = Color3.new(0, 0, 0)
        Text.TextStrokeTransparency = 0.25
        Text.ZIndex = 11
        Text.Visible = false
        Text.Parent = ScreenGui
        return Text
    end

    local function CreateVisuals(Player)
        local Box = Instance.new("Frame")
        Box.Name = "ESP_" .. Player.Name
        Box.BackgroundTransparency = 1
        Box.BorderSizePixel = 0
        Box.Visible = false
        Box.ZIndex = 10
        Box.Parent = ScreenGui

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Settings.VisibleColor or Color3.fromRGB(90, 255, 130)
        Stroke.Thickness = Settings.BoxThickness or 1
        Stroke.LineJoinMode = Enum.LineJoinMode.Miter
        Stroke.Enabled = false
        Stroke.Parent = Box

        local Corners = {}

        for Index = 1, 8 do
            local Line = Instance.new("Frame")
            Line.Name = "Corner" .. Index
            Line.BorderSizePixel = 0
            Line.BackgroundColor3 = Settings.VisibleColor or Color3.fromRGB(90, 255, 130)
            Line.Visible = false
            Line.ZIndex = 11
            Line.Parent = Box
            Corners[Index] = Line
        end

        local NameLabel = CreateText()
        NameLabel.Text = Player.Name

        return {
            Box = Box,
            Stroke = Stroke,
            Corners = Corners,
            Name = NameLabel,
            Health = CreateText(),
            Weapon = CreateText(),
            Distance = CreateText(),
        }
    end

    local function HideEntity(Data)
        if not Data or not Data.Visuals or Data.Hidden then
            return
        end

        Data.Hidden = true

        local Visuals = Data.Visuals
        Visuals.Box.Visible = false
        Visuals.Name.Visible = false
        Visuals.Health.Visible = false
        Visuals.Weapon.Visible = false
        Visuals.Distance.Visible = false

        -- Force a complete visual refresh when it becomes visible again,
        -- without allocating a new state table.
        table.clear(Data.RenderState)
    end

    ---------------------------------------------------------
    -- BODY CACHE
    ---------------------------------------------------------

    local function IsBodyPart(Object)
        if not Object:IsA("BasePart") then
            return false
        end

        if not BodyPartNames[Object.Name] then
            return false
        end

        if Object:FindFirstAncestorWhichIsA("Accessory") then
            return false
        end

        if Object:FindFirstAncestorWhichIsA("Tool") then
            return false
        end

        return true
    end

    local function AddBodyPart(Data, Object)
        if not IsBodyPart(Object) then
            return
        end

        Data.BodyParts[Object] = true

        if Object.Name == "Head" then
            Data.Head = Object
        elseif Object.Name == "UpperTorso" then
            Data.UpperTorso = Object
        elseif Object.Name == "LowerTorso" then
            Data.LowerTorso = Object
        elseif Object.Name == "Torso" then
            Data.Torso = Object
        end
    end

    local function RemoveBodyPart(Data, Object)
        Data.BodyParts[Object] = nil

        if Data.Head == Object then
            Data.Head = nil
        end

        if Data.UpperTorso == Object then
            Data.UpperTorso = nil
        end

        if Data.LowerTorso == Object then
            Data.LowerTorso = nil
        end

        if Data.Torso == Object then
            Data.Torso = nil
        end
    end

    ---------------------------------------------------------
    -- HUMANOID CACHE
    ---------------------------------------------------------

    local function DisconnectConnection(Connection)
        if Connection then
            pcall(Connection.Disconnect, Connection)
        end
    end

    local function BindHumanoid(Data, Humanoid)
        DisconnectConnection(Data.Connections.HumanoidHealth)
        DisconnectConnection(Data.Connections.HumanoidMaxHealth)

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
        local WeaponObject, SawTool = FindWeapon(Data.Character)

        Data.LastWeaponCheck = Now
        Data.WeaponObject = WeaponObject
        Data.WeaponName = WeaponObject and WeaponObject.Name or nil

        -- Only probe for delayed attributes when an actual Tool exists.
        -- Unarmed players do not perform a Character:GetChildren scan every 0.5s.
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
    -- ENTITY LIST
    ---------------------------------------------------------

    local function AddToEntityList(Data)
        local Index = #EntityList + 1
        EntityList[Index] = Data
        Data.ListIndex = Index
    end

    local function RemoveFromEntityList(Data)
        local Index = Data.ListIndex

        if not Index then
            return
        end

        local LastIndex = #EntityList
        local LastData = EntityList[LastIndex]

        EntityList[LastIndex] = nil

        if Index < LastIndex then
            EntityList[Index] = LastData
            LastData.ListIndex = Index
        end

        Data.ListIndex = nil

        local Count = #EntityList

        if Count == 0 then
            SchedulerCursor = 1
            SchedulerAccumulator = 0
        elseif SchedulerCursor > Count then
            SchedulerCursor = 1
        end
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

        local Root = Character:FindFirstChild("HumanoidRootPart")

        if Root and not Root:IsA("BasePart") then
            Root = nil
        end

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

            Visuals = CreateVisuals(Player),
            Connections = {},

            Bounds = {
                MinX = math.huge,
                MinY = math.huge,
                MaxX = -math.huge,
                MaxY = -math.huge,
                HasPoint = false,
                X = 0,
                Y = 0,
                Width = 0,
                Height = 0,
                CenterX = 0,
                CenterY = 0,
            },

            RenderState = {},
            Hidden = false,

            HealthDirty = true,
            HealthText = "",
            HealthColor = Settings.TextColor or Color3.new(1, 1, 1),
            LastDynamicHealth = nil,
            LastHealthTextColor = nil,

            LastDistanceRounded = nil,
            DistanceText = "",

            LastVisibilityCheck = 0,
            LastVisibility = false,
        }

        Entities[Character] = Data
        AddToEntityList(Data)

        for _, Object in ipairs(Character:GetDescendants()) do
            AddBodyPart(Data, Object)
        end

        BindHumanoid(
            Data,
            Character:FindFirstChildOfClass("Humanoid")
        )

        RefreshWeapon(Data)

        Data.Connections.DescendantAdded =
            Character.DescendantAdded:Connect(function(Object)
                AddBodyPart(Data, Object)

                if
                    Object.Name == "HumanoidRootPart"
                    and Object:IsA("BasePart")
                then
                    Data.Root = Object
                elseif
                    Object:IsA("Humanoid")
                    and not Data.Humanoid
                then
                    BindHumanoid(Data, Object)
                end
            end)

        Data.Connections.DescendantRemoving =
            Character.DescendantRemoving:Connect(function(Object)
                RemoveBodyPart(Data, Object)

                if Data.Root == Object then
                    Data.Root = nil
                end

                if Data.Humanoid == Object then
                    BindHumanoid(Data, nil)
                end
            end)

        Data.Connections.ChildAdded =
            Character.ChildAdded:Connect(function(Object)
                if Object:IsA("Tool") then
                    Data.WeaponProbeUntil = os.clock() + 2
                    task.defer(RefreshWeapon, Data)
                end
            end)

        Data.Connections.ChildRemoved =
            Character.ChildRemoved:Connect(function(Object)
                if
                    Object == Data.WeaponObject
                    or Object:IsA("Tool")
                then
                    task.defer(RefreshWeapon, Data)
                end
            end)

        -- Visuals are already invisible, but this initializes the hidden state.
        HideEntity(Data)
    end

    local function UnregisterEntity(Character)
        local Data = Entities[Character]

        if not Data then
            return
        end

        RemoveFromEntityList(Data)

        for _, Connection in pairs(Data.Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Data.Connections)

        if Data.Visuals then
            if Data.Visuals.Box then
                pcall(Data.Visuals.Box.Destroy, Data.Visuals.Box)
            end

            for _, Name in ipairs({
                "Name",
                "Health",
                "Weapon",
                "Distance",
            }) do
                local Object = Data.Visuals[Name]

                if Object then
                    pcall(Object.Destroy, Object)
                end
            end
        end

        Entities[Character] = nil
    end

    ---------------------------------------------------------
    -- PLAYER TRACKER
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
                RegisterEntity(Player, Character)
            end)

        Set.CharacterRemoving =
            Player.CharacterRemoving:Connect(function(Character)
                UnregisterEntity(Character)
            end)

        if Player.Character then
            RegisterEntity(Player, Player.Character)
        end
    end

    ---------------------------------------------------------
    -- TEAM CHECK
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

    ---------------------------------------------------------
    -- HEALTH
    ---------------------------------------------------------

    local function UpdateHealthCache(Data, Humanoid, TextColor)
        local Dynamic = Settings.DynamicHealthColor == true
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
                local MaxHealth = math.max(Humanoid.MaxHealth, 1)
                local Ratio = math.clamp(Humanoid.Health / MaxHealth, 0, 1)

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
    -- VISIBILITY CHECK
    ---------------------------------------------------------

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
            < VISIBILITY_INTERVAL
        then
            return Data.LastVisibility
        end

        Data.LastVisibilityCheck = Now

        local Target = FindVisibilityTarget(Data, Root)

        if not Target or not Target:IsA("BasePart") then
            Data.LastVisibility = false
            return false
        end

        table.clear(VisibilityIgnore)
        VisibilityIgnore[1] = Camera

        if LocalPlayer.Character then
            VisibilityIgnore[2] = LocalPlayer.Character
        end

        VisibilityParams.FilterDescendantsInstances = VisibilityIgnore

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
                and Result.Instance:IsDescendantOf(Data.Character)
            )

        Data.LastVisibility = Visible
        return Visible
    end

    ---------------------------------------------------------
    -- SCREEN BOUNDS / CALIBRATED PROJECTION ENGINE
    ---------------------------------------------------------

    -- The old path called Camera:WorldToViewportPoint for every corner.
    -- R15 can require roughly 120 calls per entity update.
    --
    -- We now calibrate the camera projection once per rendered frame
    -- with three native projections, then project the exact same eight
    -- corners using camera-space math.
    --
    -- A legacy fallback is kept for unusual/invalid camera states.

    local Projection = {
        Valid = false,

        CameraCFrame = CFrame.new(),

        CenterX = 0,
        CenterY = 0,

        FocalX = 0,
        FocalY = 0,

        ViewportX = 0,
        ViewportY = 0,
    }

    local function UpdateProjection(Camera)
        local ProjectionStart =
            ProfileBegin(
                "Projection.Setup"
            )

        local CameraCFrame =
            Camera.CFrame

        local CameraPosition =
            CameraCFrame.Position

        -- One stud in front of the camera.
        local CenterWorld =
            CameraPosition
            + CameraCFrame.LookVector

        local RightWorld =
            CenterWorld
            + CameraCFrame.RightVector

        local UpWorld =
            CenterWorld
            + CameraCFrame.UpVector

        local CenterScreen =
            Camera:WorldToViewportPoint(
                CenterWorld
            )

        local RightScreen =
            Camera:WorldToViewportPoint(
                RightWorld
            )

        local UpScreen =
            Camera:WorldToViewportPoint(
                UpWorld
            )

        local FocalX =
            RightScreen.X
            - CenterScreen.X

        local FocalY =
            CenterScreen.Y
            - UpScreen.Y

        local Viewport =
            Camera.ViewportSize

        Projection.CameraCFrame =
            CameraCFrame

        Projection.CenterX =
            CenterScreen.X

        Projection.CenterY =
            CenterScreen.Y

        Projection.FocalX =
            FocalX

        Projection.FocalY =
            FocalY

        Projection.ViewportX =
            Viewport.X

        Projection.ViewportY =
            Viewport.Y

        Projection.Valid =
            CenterScreen.Z > 0.05
            and math.abs(FocalX) > 0.001
            and math.abs(FocalY) > 0.001
            and Viewport.X > 0
            and Viewport.Y > 0

        ProfileFinish(
            "Projection.Setup",
            ProjectionStart
        )
    end

    local function AddFastProjectedCorner(
        Bounds,
        CameraX,
        CameraY,
        CameraZ
    )
        local Depth =
            -CameraZ

        -- Same near-plane cutoff used by the old native path.
        if Depth <= 0.05 then
            return
        end

        local ScreenX =
            Projection.CenterX
            + (
                CameraX
                * Projection.FocalX
                / Depth
            )

        local ScreenY =
            Projection.CenterY
            - (
                CameraY
                * Projection.FocalY
                / Depth
            )

        Bounds.HasPoint =
            true

        if ScreenX < Bounds.MinX then
            Bounds.MinX = ScreenX
        end

        if ScreenY < Bounds.MinY then
            Bounds.MinY = ScreenY
        end

        if ScreenX > Bounds.MaxX then
            Bounds.MaxX = ScreenX
        end

        if ScreenY > Bounds.MaxY then
            Bounds.MaxY = ScreenY
        end
    end

    local function AddLegacyProjectedCorner(
        Camera,
        Bounds,
        PartCFrame,
        OffsetX,
        OffsetY,
        OffsetZ
    )
        local WorldPosition =
            PartCFrame:PointToWorldSpace(
                Vector3.new(
                    OffsetX,
                    OffsetY,
                    OffsetZ
                )
            )

        local ScreenPosition =
            Camera:WorldToViewportPoint(
                WorldPosition
            )

        if ScreenPosition.Z <= 0.05 then
            return
        end

        Bounds.HasPoint =
            true

        if ScreenPosition.X < Bounds.MinX then
            Bounds.MinX = ScreenPosition.X
        end

        if ScreenPosition.Y < Bounds.MinY then
            Bounds.MinY = ScreenPosition.Y
        end

        if ScreenPosition.X > Bounds.MaxX then
            Bounds.MaxX = ScreenPosition.X
        end

        if ScreenPosition.Y > Bounds.MaxY then
            Bounds.MaxY = ScreenPosition.Y
        end
    end

    local function ProjectPartLegacy(
        Part,
        Camera,
        Bounds
    )
        local Size =
            Part.Size

        local X =
            Size.X * 0.5

        local Y =
            Size.Y * 0.5

        local Z =
            Size.Z * 0.5

        local PartCFrame =
            Part.CFrame

        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame, -X, -Y, -Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame, -X, -Y,  Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame, -X,  Y, -Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame, -X,  Y,  Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame,  X, -Y, -Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame,  X, -Y,  Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame,  X,  Y, -Z)
        AddLegacyProjectedCorner(Camera, Bounds, PartCFrame,  X,  Y,  Z)
    end

    local function ProjectPartFast(
        Part,
        Bounds
    )
        local Size =
            Part.Size

        local X =
            Size.X * 0.5

        local Y =
            Size.Y * 0.5

        local Z =
            Size.Z * 0.5

        -- One CFrame transform replaces eight world->viewport transforms.
        local CameraPartCFrame =
            Projection.CameraCFrame:
                ToObjectSpace(
                    Part.CFrame
                )

        local PX,
            PY,
            PZ,
            R00,
            R01,
            R02,
            R10,
            R11,
            R12,
            R20,
            R21,
            R22 =
                CameraPartCFrame:
                    GetComponents()

        -- Precompute each local half-axis contribution.
        local XX = R00 * X
        local XY = R01 * Y
        local XZ = R02 * Z

        local YX = R10 * X
        local YY = R11 * Y
        local YZ = R12 * Z

        local ZX = R20 * X
        local ZY = R21 * Y
        local ZZ = R22 * Z

        -- Exact same eight corners as the legacy implementation.
        AddFastProjectedCorner(
            Bounds,
            PX - XX - XY - XZ,
            PY - YX - YY - YZ,
            PZ - ZX - ZY - ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX - XX - XY + XZ,
            PY - YX - YY + YZ,
            PZ - ZX - ZY + ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX - XX + XY - XZ,
            PY - YX + YY - YZ,
            PZ - ZX + ZY - ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX - XX + XY + XZ,
            PY - YX + YY + YZ,
            PZ - ZX + ZY + ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX + XX - XY - XZ,
            PY + YX - YY - YZ,
            PZ + ZX - ZY - ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX + XX - XY + XZ,
            PY + YX - YY + YZ,
            PZ + ZX - ZY + ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX + XX + XY - XZ,
            PY + YX + YY - YZ,
            PZ + ZX + ZY - ZZ
        )

        AddFastProjectedCorner(
            Bounds,
            PX + XX + XY + XZ,
            PY + YX + YY + YZ,
            PZ + ZX + ZY + ZZ
        )
    end

    local function RootIsInFront(
        Camera,
        Root
    )
        if Projection.Valid then
            local CameraPosition =
                Projection.CameraCFrame:
                    PointToObjectSpace(
                        Root.Position
                    )

            return
                -CameraPosition.Z
                > 0.05
        end

        local RootScreen =
            Camera:WorldToViewportPoint(
                Root.Position
            )

        return
            RootScreen.Z
            > 0.05
    end

    local function GetCharacterBounds(Data, Camera, Root, StyleSettings)
        if not RootIsInFront(Camera, Root) then
            return nil
        end

        local Bounds = Data.Bounds
        Bounds.MinX = math.huge
        Bounds.MinY = math.huge
        Bounds.MaxX = -math.huge
        Bounds.MaxY = -math.huge
        Bounds.HasPoint = false

        if Projection.Valid then
            for Part in pairs(Data.BodyParts) do
                if Part.Parent then
                    ProjectPartFast(
                        Part,
                        Bounds
                    )
                else
                    RemoveBodyPart(
                        Data,
                        Part
                    )
                end
            end
        else
            for Part in pairs(Data.BodyParts) do
                if Part.Parent then
                    ProjectPartLegacy(
                        Part,
                        Camera,
                        Bounds
                    )
                else
                    RemoveBodyPart(
                        Data,
                        Part
                    )
                end
            end
        end

        if not Bounds.HasPoint then
            return nil
        end

        local ViewportX
        local ViewportY

        if Projection.Valid then
            ViewportX = Projection.ViewportX
            ViewportY = Projection.ViewportY
        else
            local Viewport =
                Camera.ViewportSize

            ViewportX = Viewport.X
            ViewportY = Viewport.Y
        end

        if
            Bounds.MaxX < 0
            or Bounds.MinX > ViewportX
            or Bounds.MaxY < 0
            or Bounds.MinY > ViewportY
        then
            return nil
        end

        StyleSettings = StyleSettings or Settings

        local Padding =
            tonumber(
                StyleSettings.BoxPadding
            )
            or 2

        local X =
            Bounds.MinX
            - Padding

        local Y =
            Bounds.MinY
            - Padding

        local Width =
            (
                Bounds.MaxX
                - Bounds.MinX
            )
            + Padding * 2

        local Height =
            (
                Bounds.MaxY
                - Bounds.MinY
            )
            + Padding * 2

        if Width <= 2 or Height <= 2 then
            return nil
        end

        Bounds.X = X
        Bounds.Y = Y
        Bounds.Width = Width
        Bounds.Height = Height
        Bounds.CenterX = X + Width / 2
        Bounds.CenterY = Y + Height / 2

        return Bounds
    end

    ---------------------------------------------------------
    -- VISUAL STATE HELPERS
    ---------------------------------------------------------

    local function SetVisible(State, Key, Object, Value)
        if State[Key] ~= Value then
            Object.Visible = Value
            State[Key] = Value
        end
    end

    local function SetText(State, Key, Object, Value)
        if State[Key] ~= Value then
            Object.Text = Value
            State[Key] = Value
        end
    end

    local function SetTextColor(State, Key, Object, Value)
        if State[Key] ~= Value then
            Object.TextColor3 = Value
            State[Key] = Value
        end
    end

    ---------------------------------------------------------
    -- CORNER BOX
    ---------------------------------------------------------

    local function UpdateCornerBox(Data, Width, Height, Color, StyleSettings)
        local Visuals = Data.Visuals
        local State = Data.RenderState
        StyleSettings = StyleSettings or Settings

        local Thickness =
            math.max(
                1,
                tonumber(StyleSettings.BoxThickness) or 1
            )

        local Ratio =
            math.clamp(
                tonumber(StyleSettings.CornerRatio) or 0.25,
                0.05,
                0.50
            )

        local Corner =
            math.max(
                5,
                math.floor(
                    math.min(Width, Height)
                    * Ratio
                )
            )

        Corner = math.min(Corner, Width / 2, Height / 2)

        -- If the integer box geometry and style did not change, all eight
        -- corner frames can keep their previous geometry/color.
        if
            State.CornerWidth == Width
            and State.CornerHeight == Height
            and State.CornerThickness == Thickness
            and State.CornerLength == Corner
            and State.CornerColor == Color
        then
            return
        end

        State.CornerWidth = Width
        State.CornerHeight = Height
        State.CornerThickness = Thickness
        State.CornerLength = Corner
        State.CornerColor = Color

        local C = Visuals.Corners

        for _, Line in ipairs(C) do
            Line.BackgroundColor3 = Color
        end

        C[1].Position = UDim2.fromOffset(0, 0)
        C[1].Size = UDim2.fromOffset(Corner, Thickness)
        C[2].Position = UDim2.fromOffset(0, 0)
        C[2].Size = UDim2.fromOffset(Thickness, Corner)

        C[3].Position = UDim2.fromOffset(Width - Corner, 0)
        C[3].Size = UDim2.fromOffset(Corner, Thickness)
        C[4].Position = UDim2.fromOffset(Width - Thickness, 0)
        C[4].Size = UDim2.fromOffset(Thickness, Corner)

        C[5].Position = UDim2.fromOffset(0, Height - Thickness)
        C[5].Size = UDim2.fromOffset(Corner, Thickness)
        C[6].Position = UDim2.fromOffset(0, Height - Corner)
        C[6].Size = UDim2.fromOffset(Thickness, Corner)

        C[7].Position = UDim2.fromOffset(Width - Corner, Height - Thickness)
        C[7].Size = UDim2.fromOffset(Corner, Thickness)
        C[8].Position = UDim2.fromOffset(Width - Thickness, Height - Corner)
        C[8].Size = UDim2.fromOffset(Thickness, Corner)
    end

    ---------------------------------------------------------
    -- UPDATE ENTITY
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
            HideEntity(Data)
            return
        end

        if IsTeammate(Data) then
            HideEntity(Data)
            return
        end

        -----------------------------------------------------
        -- STREAMING-AWARE ROOT / HUMANOID
        -----------------------------------------------------

        local Root = Data.Root
        local Humanoid = Data.Humanoid

        if
            not Root
            or not Root.Parent
            or not Humanoid
            or not Humanoid.Parent
            or Humanoid.Health <= 0
        then
            HideEntity(Data)
            return
        end

        -----------------------------------------------------
        -- WEAPON DELAYED-ATTRIBUTE PROBE
        -----------------------------------------------------

        local Now = os.clock()

        if
            not Data.WeaponObject
            and Data.WeaponProbeUntil > Now
            and Now - Data.LastWeaponCheck >= 0.25
        then
            RefreshWeapon(Data)
        end

        -----------------------------------------------------
        -- DISTANCE
        -----------------------------------------------------

        local Distance =
            (
                Root.Position
                - Camera.CFrame.Position
            ).Magnitude

        local MaxDistance = tonumber(Settings.MaxDistance) or 1000

        if Distance > MaxDistance then
            HideEntity(Data)
            return
        end

        -----------------------------------------------------
        -- BOUNDS
        -----------------------------------------------------

        local BoundsStart =
            ProfileBegin(
                "Players.Bounds"
            )

        local Bounds =
            GetCharacterBounds(
                Data,
                Camera,
                Root,
                Settings
            )

        ProfileFinish(
            "Players.Bounds",
            BoundsStart
        )

        if not Bounds then
            HideEntity(Data)
            return
        end

        -----------------------------------------------------
        -- VISIBILITY / COLORS
        -----------------------------------------------------

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

        local VisibleColor = Settings.VisibleColor or Color3.fromRGB(90, 255, 130)
        local HiddenColor = Settings.HiddenColor or Color3.fromRGB(255, 90, 90)

        local BoxColor = VisibleColor

        if Settings.VisibilityCheck and not Visible then
            BoxColor = HiddenColor
        end

        local TextColor = Settings.TextColor or Color3.new(1, 1, 1)
        UpdateHealthCache(Data, Humanoid, TextColor)

        local VisualStart =
            ProfileBegin(
                "Players.Visuals"
            )

        -----------------------------------------------------
        -- DISTANCE TEXT CACHE
        -----------------------------------------------------

        local DistanceRounded = math.floor(Distance + 0.5)

        if Data.LastDistanceRounded ~= DistanceRounded then
            Data.LastDistanceRounded = DistanceRounded
            Data.DistanceText = tostring(DistanceRounded) .. " studs"
        end

        -----------------------------------------------------
        -- VISUALS
        -----------------------------------------------------

        Data.Hidden = false

        local Visuals = Data.Visuals
        local State = Data.RenderState

        local BoxWidth = math.floor(Bounds.Width)
        local BoxHeight = math.floor(Bounds.Height)
        local BoxX = math.floor(Bounds.X)
        local BoxY = math.floor(Bounds.Y)

        local BoxEnabled = Settings.Box == true
        local CornerStyle = (Settings.BoxStyle or "Corner") == "Corner"

        if BoxEnabled then
            if
                State.BoxX ~= BoxX
                or State.BoxY ~= BoxY
            then
                Visuals.Box.Position = UDim2.fromOffset(BoxX, BoxY)
                State.BoxX = BoxX
                State.BoxY = BoxY
            end

            if
                State.BoxWidth ~= BoxWidth
                or State.BoxHeight ~= BoxHeight
            then
                Visuals.Box.Size = UDim2.fromOffset(BoxWidth, BoxHeight)
                State.BoxWidth = BoxWidth
                State.BoxHeight = BoxHeight
            end
        end

        SetVisible(State, "BoxVisible", Visuals.Box, BoxEnabled)

        if BoxEnabled and CornerStyle then
            if State.StrokeEnabled ~= false then
                Visuals.Stroke.Enabled = false
                State.StrokeEnabled = false
            end

            if State.CornersVisible ~= true then
                for _, Line in ipairs(Visuals.Corners) do
                    Line.Visible = true
                end

                State.CornersVisible = true
            end

            UpdateCornerBox(
                Data,
                BoxWidth,
                BoxHeight,
                BoxColor,
                Settings
            )
        elseif BoxEnabled then
            if State.CornersVisible ~= false then
                for _, Line in ipairs(Visuals.Corners) do
                    Line.Visible = false
                end

                State.CornersVisible = false
            end

            if State.StrokeEnabled ~= true then
                Visuals.Stroke.Enabled = true
                State.StrokeEnabled = true
            end

            local Thickness = tonumber(Settings.BoxThickness) or 1

            if State.StrokeColor ~= BoxColor then
                Visuals.Stroke.Color = BoxColor
                State.StrokeColor = BoxColor
            end

            if State.StrokeThickness ~= Thickness then
                Visuals.Stroke.Thickness = Thickness
                State.StrokeThickness = Thickness
            end
        end

        -----------------------------------------------------
        -- TEXT COLORS
        -----------------------------------------------------

        SetTextColor(State, "NameColor", Visuals.Name, TextColor)
        SetTextColor(State, "WeaponColor", Visuals.Weapon, TextColor)
        SetTextColor(State, "DistanceColor", Visuals.Distance, TextColor)
        SetTextColor(State, "HealthColor", Visuals.Health, Data.HealthColor)

        -----------------------------------------------------
        -- NAME
        -----------------------------------------------------

        local ShowName = Settings.Name == true
        SetVisible(State, "NameVisible", Visuals.Name, ShowName)

        if ShowName then
            Visuals.Name.Position =
                UDim2.fromOffset(
                    Bounds.CenterX,
                    Bounds.Y - 12
                )
        end

        -----------------------------------------------------
        -- BOTTOM TEXT STACK
        -----------------------------------------------------

        local NextY = Bounds.Y + Bounds.Height + 10

        local ShowHealth = Settings.Health == true
        SetVisible(State, "HealthVisible", Visuals.Health, ShowHealth)

        if ShowHealth then
            SetText(State, "HealthText", Visuals.Health, Data.HealthText)
            Visuals.Health.Position = UDim2.fromOffset(Bounds.CenterX, NextY)
            NextY += 17
        end

        local WeaponName = Data.WeaponName
        local ShowWeapon =
            Settings.Weapon == true
            and type(WeaponName) == "string"
            and WeaponName ~= ""

        SetVisible(State, "WeaponVisible", Visuals.Weapon, ShowWeapon)

        if ShowWeapon then
            SetText(State, "WeaponText", Visuals.Weapon, WeaponName)
            Visuals.Weapon.Position = UDim2.fromOffset(Bounds.CenterX, NextY)
            NextY += 17
        end

        local ShowDistance = Settings.Distance == true
        SetVisible(State, "DistanceVisible", Visuals.Distance, ShowDistance)

        if ShowDistance then
            SetText(State, "DistanceText", Visuals.Distance, Data.DistanceText)
            Visuals.Distance.Position = UDim2.fromOffset(Bounds.CenterX, NextY)
        end

        ProfileFinish(
            "Players.Visuals",
            VisualStart
        )
    end


    ---------------------------------------------------------
    -- CORPSE ESP
    ---------------------------------------------------------

    local function CreateCorpseVisuals(Corpse)
        local Box = Instance.new("Frame")
        Box.Name = "CORPSE_" .. Corpse.Name
        Box.BackgroundTransparency = 1
        Box.BorderSizePixel = 0
        Box.Visible = false
        Box.ZIndex = 10
        Box.Parent = ScreenGui

        local CorpseColor =
            CorpseSettings.Color
            or Color3.fromRGB(255, 190, 90)

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = CorpseColor
        Stroke.Thickness = CorpseSettings.BoxThickness or 1
        Stroke.LineJoinMode = Enum.LineJoinMode.Miter
        Stroke.Enabled = false
        Stroke.Parent = Box

        local Corners = {}

        for Index = 1, 8 do
            local Line = Instance.new("Frame")
            Line.Name = "Corner" .. Index
            Line.BorderSizePixel = 0
            Line.BackgroundColor3 = CorpseColor
            Line.Visible = false
            Line.ZIndex = 11
            Line.Parent = Box
            Corners[Index] = Line
        end

        local Name = CreateText()
        Name.Text = "[CORPSE] " .. Corpse.Name

        local Distance = CreateText()

        return {
            Box = Box,
            Stroke = Stroke,
            Corners = Corners,
            Name = Name,
            Distance = Distance,
        }
    end

    local function HideCorpse(Data)
        if not Data or not Data.Visuals or Data.Hidden then
            return
        end

        Data.Hidden = true

        local Visuals = Data.Visuals
        Visuals.Box.Visible = false
        Visuals.Name.Visible = false
        Visuals.Distance.Visible = false

        table.clear(Data.RenderState)
    end

    local function AddCorpseBodyPart(Data, Object)
        if
            not Object:IsA("BasePart")
            or not BodyPartNames[Object.Name]
        then
            return
        end

        if Object:FindFirstAncestorWhichIsA("Accessory") then
            return
        end

        if Object:FindFirstAncestorWhichIsA("Tool") then
            return
        end

        Data.BodyParts[Object] = true

        if
            Object.Name == "Head"
            or Object.Name == "Head2"
        then
            Data.Head = Object
        elseif Object.Name == "UpperTorso" then
            Data.UpperTorso = Object
        elseif Object.Name == "LowerTorso" then
            Data.LowerTorso = Object
        elseif Object.Name == "Torso" then
            Data.Torso = Object
        end
    end

    local function FindCorpseRoot(Corpse)
        for _, Name in ipairs({
            "HumanoidRootPart",
            "UpperTorso",
            "LowerTorso",
            "Torso",
            "Head2",
            "Head",
        }) do
            local Part = Corpse:FindFirstChild(Name)

            if Part and Part:IsA("BasePart") then
                return Part
            end
        end

        return nil
    end

    local function AddToCorpseList(Data)
        local Index = #CorpseList + 1
        CorpseList[Index] = Data
        Data.ListIndex = Index
    end

    local function RemoveFromCorpseList(Data)
        local Index = Data.ListIndex

        if not Index then
            return
        end

        local LastIndex = #CorpseList
        local LastData = CorpseList[LastIndex]

        CorpseList[LastIndex] = nil

        if Index < LastIndex then
            CorpseList[Index] = LastData
            LastData.ListIndex = Index
        end

        Data.ListIndex = nil

        local Count = #CorpseList

        if Count == 0 then
            CorpseSchedulerCursor = 1
            CorpseSchedulerAccumulator = 0
        elseif CorpseSchedulerCursor > Count then
            CorpseSchedulerCursor = 1
        end
    end

    local function RegisterCorpse(Corpse)
        if
            Destroyed
            or not Corpse
            or not Corpse:IsA("Model")
            or CorpseEntities[Corpse]
        then
            return
        end

        local Data = {
            Character = Corpse,
            Corpse = Corpse,

            Root = FindCorpseRoot(Corpse),

            Head = nil,
            UpperTorso = nil,
            LowerTorso = nil,
            Torso = nil,

            BodyParts = {},
            Visuals = CreateCorpseVisuals(Corpse),
            Connections = {},

            Bounds = {
                MinX = math.huge,
                MinY = math.huge,
                MaxX = -math.huge,
                MaxY = -math.huge,
                HasPoint = false,
                X = 0,
                Y = 0,
                Width = 0,
                Height = 0,
                CenterX = 0,
                CenterY = 0,
            },

            RenderState = {},
            Hidden = false,

            LastDistanceRounded = nil,
            DistanceText = "",
        }

        CorpseEntities[Corpse] = Data
        AddToCorpseList(Data)

        for _, Object in ipairs(Corpse:GetDescendants()) do
            AddCorpseBodyPart(Data, Object)
        end

        Data.Connections.DescendantAdded =
            Corpse.DescendantAdded:Connect(function(Object)
                AddCorpseBodyPart(Data, Object)

                if
                    Object.Name == "HumanoidRootPart"
                    and Object:IsA("BasePart")
                then
                    Data.Root = Object
                elseif not Data.Root then
                    Data.Root = FindCorpseRoot(Corpse)
                end
            end)

        Data.Connections.DescendantRemoving =
            Corpse.DescendantRemoving:Connect(function(Object)
                RemoveBodyPart(Data, Object)

                if Data.Root == Object then
                    Data.Root = nil
                    task.defer(function()
                        if Corpse.Parent then
                            Data.Root = FindCorpseRoot(Corpse)
                        end
                    end)
                end
            end)

        HideCorpse(Data)
    end

    local function UnregisterCorpse(Corpse)
        local Data = CorpseEntities[Corpse]

        if not Data then
            return
        end

        RemoveFromCorpseList(Data)

        for _, Connection in pairs(Data.Connections) do
            DisconnectConnection(Connection)
        end

        table.clear(Data.Connections)

        if Data.Visuals then
            if Data.Visuals.Box then
                pcall(Data.Visuals.Box.Destroy, Data.Visuals.Box)
            end

            if Data.Visuals.Name then
                pcall(Data.Visuals.Name.Destroy, Data.Visuals.Name)
            end

            if Data.Visuals.Distance then
                pcall(Data.Visuals.Distance.Destroy, Data.Visuals.Distance)
            end
        end

        CorpseEntities[Corpse] = nil
    end

    local function DisconnectCorpseFolder()
        for _, Connection in pairs(CorpseFolderConnections) do
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
            HideCorpse(Data)
            return
        end

        local Root = Data.Root

        if not Root or not Root.Parent then
            Root = FindCorpseRoot(Corpse)
            Data.Root = Root
        end

        if not Root then
            HideCorpse(Data)
            return
        end

        local Distance =
            (
                Root.Position
                - Camera.CFrame.Position
            ).Magnitude

        local MaxDistance =
            tonumber(CorpseSettings.MaxDistance)
            or 1000

        if Distance > MaxDistance then
            HideCorpse(Data)
            return
        end

        local BoundsStart =
            ProfileBegin(
                "Corpses.Bounds"
            )

        local Bounds =
            GetCharacterBounds(
                Data,
                Camera,
                Root,
                CorpseSettings
            )

        ProfileFinish(
            "Corpses.Bounds",
            BoundsStart
        )

        if not Bounds then
            HideCorpse(Data)
            return
        end

        local VisualStart =
            ProfileBegin(
                "Corpses.Visuals"
            )

        local DistanceRounded = math.floor(Distance + 0.5)

        if Data.LastDistanceRounded ~= DistanceRounded then
            Data.LastDistanceRounded = DistanceRounded
            Data.DistanceText = tostring(DistanceRounded) .. " studs"
        end

        Data.Hidden = false

        local Visuals = Data.Visuals
        local State = Data.RenderState

        local CorpseColor =
            CorpseSettings.Color
            or Color3.fromRGB(255, 190, 90)

        local TextColor =
            CorpseSettings.TextColor
            or Color3.fromRGB(255, 255, 255)

        local BoxWidth = math.floor(Bounds.Width)
        local BoxHeight = math.floor(Bounds.Height)
        local BoxX = math.floor(Bounds.X)
        local BoxY = math.floor(Bounds.Y)

        local BoxEnabled = CorpseSettings.Box == true
        local CornerStyle =
            (CorpseSettings.BoxStyle or "Corner")
            == "Corner"

        if BoxEnabled then
            if State.BoxX ~= BoxX or State.BoxY ~= BoxY then
                Visuals.Box.Position = UDim2.fromOffset(BoxX, BoxY)
                State.BoxX = BoxX
                State.BoxY = BoxY
            end

            if
                State.BoxWidth ~= BoxWidth
                or State.BoxHeight ~= BoxHeight
            then
                Visuals.Box.Size = UDim2.fromOffset(BoxWidth, BoxHeight)
                State.BoxWidth = BoxWidth
                State.BoxHeight = BoxHeight
            end
        end

        SetVisible(State, "BoxVisible", Visuals.Box, BoxEnabled)

        if BoxEnabled and CornerStyle then
            if State.StrokeEnabled ~= false then
                Visuals.Stroke.Enabled = false
                State.StrokeEnabled = false
            end

            if State.CornersVisible ~= true then
                for _, Line in ipairs(Visuals.Corners) do
                    Line.Visible = true
                end

                State.CornersVisible = true
            end

            UpdateCornerBox(
                Data,
                BoxWidth,
                BoxHeight,
                CorpseColor,
                CorpseSettings
            )
        elseif BoxEnabled then
            if State.CornersVisible ~= false then
                for _, Line in ipairs(Visuals.Corners) do
                    Line.Visible = false
                end

                State.CornersVisible = false
            end

            if State.StrokeEnabled ~= true then
                Visuals.Stroke.Enabled = true
                State.StrokeEnabled = true
            end

            local Thickness =
                tonumber(CorpseSettings.BoxThickness)
                or 1

            if State.StrokeColor ~= CorpseColor then
                Visuals.Stroke.Color = CorpseColor
                State.StrokeColor = CorpseColor
            end

            if State.StrokeThickness ~= Thickness then
                Visuals.Stroke.Thickness = Thickness
                State.StrokeThickness = Thickness
            end
        end

        SetTextColor(State, "NameColor", Visuals.Name, TextColor)
        SetTextColor(State, "DistanceColor", Visuals.Distance, TextColor)

        local ShowName = CorpseSettings.Name == true
        SetVisible(State, "NameVisible", Visuals.Name, ShowName)

        if ShowName then
            Visuals.Name.Position =
                UDim2.fromOffset(
                    Bounds.CenterX,
                    Bounds.Y - 12
                )
        end

        local ShowDistance = CorpseSettings.Distance == true
        SetVisible(State, "DistanceVisible", Visuals.Distance, ShowDistance)

        if ShowDistance then
            SetText(
                State,
                "DistanceText",
                Visuals.Distance,
                Data.DistanceText
            )

            Visuals.Distance.Position =
                UDim2.fromOffset(
                    Bounds.CenterX,
                    Bounds.Y + Bounds.Height + 10
                )
        end

        ProfileFinish(
            "Corpses.Visuals",
            VisualStart
        )
    end

    local CorpseFolderName =
        tostring(
            CorpseSettings.FolderName
            or "Corpses"
        )

    local ExistingCorpseFolder =
        Workspace:FindFirstChild(CorpseFolderName)

    if ExistingCorpseFolder then
        BindCorpseFolder(ExistingCorpseFolder)
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
    -- TRACK EXISTING PLAYERS
    ---------------------------------------------------------

    for _, Player in ipairs(Players:GetPlayers()) do
        TrackPlayer(Player)
    end

    ---------------------------------------------------------
    -- PLAYER EVENTS
    ---------------------------------------------------------

    Connections.PlayerAdded =
        Players.PlayerAdded:Connect(function(Player)
            TrackPlayer(Player)
        end)

    Connections.PlayerRemoving =
        Players.PlayerRemoving:Connect(function(Player)
            DisconnectPlayer(Player)
        end)

    ---------------------------------------------------------
    -- RENDER / ROUND-ROBIN SCHEDULER
    ---------------------------------------------------------

    Connections.Render =
        RunService.RenderStepped:Connect(function(DeltaTime)
            if Destroyed then
                return
            end

            ProfileFrame(
                DeltaTime
            )

            ProfileGauge(
                "PlayersTracked",
                #EntityList
            )

            ProfileGauge(
                "CorpsesTracked",
                #CorpseList
            )

            local RenderStart =
                ProfileBegin(
                    "Newz.Render"
                )

            local PlayersEnabled = Settings.Enabled == true
            local CorpsesEnabled = CorpseSettings.Enabled == true

            if not PlayersEnabled and WasEnabled then
                for _, Data in ipairs(EntityList) do
                    HideEntity(Data)
                end

                WasEnabled = false
                SchedulerAccumulator = 0
            elseif PlayersEnabled then
                WasEnabled = true
            end

            if not CorpsesEnabled and WasCorpsesEnabled then
                for _, Data in ipairs(CorpseList) do
                    HideCorpse(Data)
                end

                WasCorpsesEnabled = false
                CorpseSchedulerAccumulator = 0
            elseif CorpsesEnabled then
                WasCorpsesEnabled = true
            end

            if not PlayersEnabled and not CorpsesEnabled then
                ProfileFinish(
                    "Newz.Render",
                    RenderStart
                )

                return
            end

            local Camera = Workspace.CurrentCamera

            if not Camera then
                ProfileFinish(
                    "Newz.Render",
                    RenderStart
                )

                return
            end

            UpdateProjection(
                Camera
            )

            if PlayersEnabled then
                local Count = #EntityList

                if Count == 0 then
                    SchedulerCursor = 1
                    SchedulerAccumulator = 0
                else
                    SchedulerAccumulator =
                        math.min(
                            Count,
                            SchedulerAccumulator
                            + DeltaTime
                            * UpdateFrequency
                            * Count
                        )

                    local Budget = math.floor(SchedulerAccumulator)

                    if Budget > 0 then
                        SchedulerAccumulator -= Budget

                        for _ = 1, Budget do
                            if SchedulerCursor > Count then
                                SchedulerCursor = 1
                            end

                            local Data = EntityList[SchedulerCursor]
                            SchedulerCursor += 1

                            if Data then
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
                        end

                        ProfileCount(
                            "PlayerUpdates",
                            Budget
                        )
                    end
                end
            end

            if CorpsesEnabled then
                local Count = #CorpseList

                if Count == 0 then
                    CorpseSchedulerCursor = 1
                    CorpseSchedulerAccumulator = 0
                else
                    CorpseSchedulerAccumulator =
                        math.min(
                            Count,
                            CorpseSchedulerAccumulator
                            + DeltaTime
                            * UpdateFrequency
                            * Count
                        )

                    local Budget =
                        math.floor(
                            CorpseSchedulerAccumulator
                        )

                    if Budget > 0 then
                        CorpseSchedulerAccumulator -= Budget

                        for _ = 1, Budget do
                            if CorpseSchedulerCursor > Count then
                                CorpseSchedulerCursor = 1
                            end

                            local Data =
                                CorpseList[
                                    CorpseSchedulerCursor
                                ]

                            CorpseSchedulerCursor += 1

                            if Data then
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
                        end

                        ProfileCount(
                            "CorpseUpdates",
                            Budget
                        )
                    end
                end
            end

            ProfileFinish(
                "Newz.Render",
                RenderStart
            )
        end)

    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller = {}

    function Controller.Toggle(Value)
        Settings.Enabled = Value == true
    end

    function Controller.GetEntityCount()
        return #EntityList
    end

    function Controller.GetLocalEntity()
        return LocalPlayer.Character
    end

    function Controller.GetCorpseCount()
        return #CorpseList
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

        table.clear(EntityList)

        DisconnectCorpseFolder()
        table.clear(CorpseEntities)
        table.clear(CorpseList)

        if ScreenGui then
            pcall(ScreenGui.Destroy, ScreenGui)
        end
    end

    return Controller
end

return ESP
