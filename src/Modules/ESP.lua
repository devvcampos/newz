local ESP = {}

function ESP.Init(Config)
    ---------------------------------------------------------
    -- SERVICES / CONFIG
    ---------------------------------------------------------

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local Settings = Config.ESP
    local Runtime = Config.Runtime or {}

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
    -- SCREEN BOUNDS
    ---------------------------------------------------------

    local function AddProjectedCorner(
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

        Bounds.HasPoint = true

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

    local function ProjectPart(Part, Camera, Bounds)
        local Half = Part.Size / 2
        local X, Y, Z = Half.X, Half.Y, Half.Z
        local PartCFrame = Part.CFrame

        -- Same eight corners as before, but without creating a closure
        -- for every body part on every update.
        AddProjectedCorner(Camera, Bounds, PartCFrame, -X, -Y, -Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame, -X, -Y,  Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame, -X,  Y, -Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame, -X,  Y,  Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame,  X, -Y, -Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame,  X, -Y,  Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame,  X,  Y, -Z)
        AddProjectedCorner(Camera, Bounds, PartCFrame,  X,  Y,  Z)
    end

    local function GetCharacterBounds(Data, Camera, Root)
        local RootScreen = Camera:WorldToViewportPoint(Root.Position)

        if RootScreen.Z <= 0.05 then
            return nil
        end

        local Bounds = Data.Bounds
        Bounds.MinX = math.huge
        Bounds.MinY = math.huge
        Bounds.MaxX = -math.huge
        Bounds.MaxY = -math.huge
        Bounds.HasPoint = false

        for Part in pairs(Data.BodyParts) do
            if Part.Parent then
                ProjectPart(Part, Camera, Bounds)
            else
                RemoveBodyPart(Data, Part)
            end
        end

        if not Bounds.HasPoint then
            return nil
        end

        local Viewport = Camera.ViewportSize

        if
            Bounds.MaxX < 0
            or Bounds.MinX > Viewport.X
            or Bounds.MaxY < 0
            or Bounds.MinY > Viewport.Y
        then
            return nil
        end

        local Padding = tonumber(Settings.BoxPadding) or 2
        local X = Bounds.MinX - Padding
        local Y = Bounds.MinY - Padding
        local Width = (Bounds.MaxX - Bounds.MinX) + Padding * 2
        local Height = (Bounds.MaxY - Bounds.MinY) + Padding * 2

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

    local function UpdateCornerBox(Data, Width, Height, Color)
        local Visuals = Data.Visuals
        local State = Data.RenderState

        local Thickness =
            math.max(
                1,
                tonumber(Settings.BoxThickness) or 1
            )

        local Ratio =
            math.clamp(
                tonumber(Settings.CornerRatio) or 0.25,
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

        local Bounds = GetCharacterBounds(Data, Camera, Root)

        if not Bounds then
            HideEntity(Data)
            return
        end

        -----------------------------------------------------
        -- VISIBILITY / COLORS
        -----------------------------------------------------

        local Visible = IsEntityVisible(Data, Camera, Root)
        local VisibleColor = Settings.VisibleColor or Color3.fromRGB(90, 255, 130)
        local HiddenColor = Settings.HiddenColor or Color3.fromRGB(255, 90, 90)

        local BoxColor = VisibleColor

        if Settings.VisibilityCheck and not Visible then
            BoxColor = HiddenColor
        end

        local TextColor = Settings.TextColor or Color3.new(1, 1, 1)
        UpdateHealthCache(Data, Humanoid, TextColor)

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
                BoxColor
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
    end

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

            if not Settings.Enabled then
                if WasEnabled then
                    for _, Data in ipairs(EntityList) do
                        HideEntity(Data)
                    end

                    WasEnabled = false
                    SchedulerAccumulator = 0
                end

                return
            end

            WasEnabled = true

            local Camera = Workspace.CurrentCamera

            if not Camera then
                return
            end

            local Count = #EntityList

            if Count == 0 then
                SchedulerCursor = 1
                SchedulerAccumulator = 0
                return
            end

            -- At 60 FPS and UpdateFrequency=30 this naturally processes
            -- roughly half of the entities each rendered frame. At higher
            -- FPS the budget becomes smaller, keeping each entity near the
            -- same 30 Hz average without one large 30 Hz spike.
            SchedulerAccumulator =
                math.min(
                    Count,
                    SchedulerAccumulator
                    + DeltaTime
                    * UpdateFrequency
                    * Count
                )

            local Budget = math.floor(SchedulerAccumulator)

            if Budget < 1 then
                return
            end

            SchedulerAccumulator -= Budget

            for _ = 1, Budget do
                if SchedulerCursor > Count then
                    SchedulerCursor = 1
                end

                local Data = EntityList[SchedulerCursor]
                SchedulerCursor += 1

                if Data then
                    UpdateEntity(Data, Camera)
                end
            end
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

        if ScreenGui then
            pcall(ScreenGui.Destroy, ScreenGui)
        end
    end

    return Controller
end

return ESP
