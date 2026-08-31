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

    assert(
        LocalPlayer,
        "ESP precisa ser inicializado no cliente"
    )

    ---------------------------------------------------------
    -- STATE
    ---------------------------------------------------------

    local Destroyed = false

    -- [Character] = Data
    local Entities = {}

    -- Global connections
    local Connections = {}

    -- [Player] = {
    --     CharacterAdded = connection,
    --     CharacterRemoving = connection,
    -- }
    local PlayerConnections = {}

    ---------------------------------------------------------
    -- PERFORMANCE
    ---------------------------------------------------------

    local UpdateFrequency =
        math.clamp(
            tonumber(
                Runtime.UpdateFrequency
            )
            or 30,
            1,
            240
        )

    local UPDATE_RATE =
        1 / UpdateFrequency

    local VISIBILITY_INTERVAL =
        math.max(
            0.01,
            tonumber(
                Runtime.VisibilityInterval
            )
            or 0.10
        )

    local UpdateAccumulator = 0

    ---------------------------------------------------------
    -- VISIBILITY
    ---------------------------------------------------------

    local VisibilityParams =
        RaycastParams.new()

    VisibilityParams.FilterType =
        Enum.RaycastFilterType.Exclude

    VisibilityParams.IgnoreWater =
        true

    ---------------------------------------------------------
    -- R6 / R15 BODY PARTS
    ---------------------------------------------------------

    local BodyPartNames = {

        -----------------------------------------------------
        -- R6
        -----------------------------------------------------

        ["Head"] = true,
        ["Torso"] = true,

        ["Left Arm"] = true,
        ["Right Arm"] = true,

        ["Left Leg"] = true,
        ["Right Leg"] = true,

        -----------------------------------------------------
        -- R15
        -----------------------------------------------------

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

    local PlayerGui =
        LocalPlayer:
            WaitForChild(
                "PlayerGui"
            )

    local OldGui =
        PlayerGui:
            FindFirstChild(
                "newz_ESP"
            )

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui =
        Instance.new(
            "ScreenGui"
        )

    ScreenGui.Name =
        "newz_ESP"

    ScreenGui.ResetOnSpawn =
        false

    ScreenGui.IgnoreGuiInset =
        true

    ScreenGui.DisplayOrder =
        999

    ScreenGui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    ScreenGui.Parent =
        PlayerGui

    ---------------------------------------------------------
    -- VISUAL HELPERS
    ---------------------------------------------------------

    local function CreateText()

        local Text =
            Instance.new(
                "TextLabel"
            )

        Text.BackgroundTransparency =
            1

        Text.Size =
            UDim2.fromOffset(
                220,
                18
            )

        Text.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        Text.Font =
            Enum.Font.Gotham

        Text.TextSize =
            13

        Text.TextColor3 =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        Text.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )

        Text.TextStrokeTransparency =
            0.25

        Text.ZIndex =
            11

        Text.Visible =
            false

        Text.Parent =
            ScreenGui

        return Text
    end

    local function CreateVisuals(Player)

        local Box =
            Instance.new(
                "Frame"
            )

        Box.Name =
            "ESP_"
            .. Player.Name

        Box.BackgroundTransparency =
            1

        Box.BorderSizePixel =
            0

        Box.Visible =
            false

        Box.ZIndex =
            10

        Box.Parent =
            ScreenGui

        local Stroke =
            Instance.new(
                "UIStroke"
            )

        Stroke.Color =
            Settings.VisibleColor
            or Color3.fromRGB(
                90,
                255,
                130
            )

        Stroke.Thickness =
            Settings.BoxThickness
            or 1

        Stroke.LineJoinMode =
            Enum.LineJoinMode.Miter

        Stroke.Enabled =
            false

        Stroke.Parent =
            Box

        local Corners = {}

        for Index = 1, 8 do

            local Line =
                Instance.new(
                    "Frame"
                )

            Line.Name =
                "Corner"
                .. Index

            Line.BorderSizePixel =
                0

            Line.BackgroundColor3 =
                Settings.VisibleColor
                or Color3.fromRGB(
                    90,
                    255,
                    130
                )

            Line.Visible =
                false

            Line.ZIndex =
                11

            Line.Parent =
                Box

            Corners[Index] =
                Line
        end

        return {
            Box = Box,
            Stroke = Stroke,
            Corners = Corners,

            Name = CreateText(),
            Health = CreateText(),
            Weapon = CreateText(),
            Distance = CreateText(),
        }
    end

    local function HideEntity(Data)

        if
            not Data
            or not Data.Visuals
        then
            return
        end

        local Visuals =
            Data.Visuals

        Visuals.Box.Visible =
            false

        Visuals.Name.Visible =
            false

        Visuals.Health.Visible =
            false

        Visuals.Weapon.Visible =
            false

        Visuals.Distance.Visible =
            false
    end

    ---------------------------------------------------------
    -- BODY CACHE
    ---------------------------------------------------------

    local function IsBodyPart(Object)

        if
            not Object:IsA(
                "BasePart"
            )
        then
            return false
        end

        if
            not BodyPartNames[
                Object.Name
            ]
        then
            return false
        end

        -----------------------------------------------------
        -- ACCESSORIES
        -----------------------------------------------------

        if
            Object:
                FindFirstAncestorWhichIsA(
                    "Accessory"
                )
        then
            return false
        end

        -----------------------------------------------------
        -- TOOLS
        -----------------------------------------------------

        if
            Object:
                FindFirstAncestorWhichIsA(
                    "Tool"
                )
        then
            return false
        end

        return true
    end

    local function AddBodyPart(
        Data,
        Object
    )

        if IsBodyPart(Object) then

            Data.BodyParts[
                Object
            ] =
                true
        end
    end

    ---------------------------------------------------------
    -- WEAPON TRACKING
    ---------------------------------------------------------

    local function IsEquippedWeapon(
        Object,
        Character
    )

        if
            not Object
            or Object.Parent ~= Character
            or not Object:IsA(
                "Tool"
            )
        then
            return false
        end

        return
            Object:GetAttribute(
                "Type"
            ) == "Gun"
            or Object:GetAttribute(
                "GunBound"
            ) == true
    end

    local function FindWeapon(
        Character
    )

        for _, Object
            in ipairs(
                Character:
                    GetChildren()
            )
        do

            if
                IsEquippedWeapon(
                    Object,
                    Character
                )
            then
                return Object
            end
        end

        return nil
    end

    local function RefreshWeapon(
        Data
    )

        if
            not Data
            or not Data.Character
            or not Data.Character.Parent
        then
            return
        end

        Data.LastWeaponCheck =
            os.clock()

        Data.WeaponObject =
            FindWeapon(
                Data.Character
            )

        Data.WeaponName =
            Data.WeaponObject
            and Data.WeaponObject.Name
            or nil
    end

    ---------------------------------------------------------
    -- ENTITY LIFECYCLE
    ---------------------------------------------------------

    local function RegisterEntity(
        Player,
        Character
    )

        if Destroyed then
            return
        end

        if
            not Player
            or Player == LocalPlayer
            or not Character
            or not Character:IsA(
                "Model"
            )
        then
            return
        end

        if Entities[Character] then
            return
        end

        local Data = {
            Player = Player,
            Character = Character,

            BodyParts = {},

            WeaponObject = nil,
            WeaponName = nil,
            LastWeaponCheck = 0,

            Visuals =
                CreateVisuals(
                    Player
                ),

            Connections = {},

            LastVisibilityCheck = 0,
            LastVisibility = false,
        }

        Entities[Character] =
            Data

        -----------------------------------------------------
        -- EXISTING STREAMED PARTS
        -----------------------------------------------------

        for _, Object
            in ipairs(
                Character:
                    GetDescendants()
            )
        do

            AddBodyPart(
                Data,
                Object
            )
        end

        RefreshWeapon(
            Data
        )

        -----------------------------------------------------
        -- STREAMING IN
        -----------------------------------------------------

        Data.Connections.DescendantAdded =
            Character.DescendantAdded:
                Connect(function(Object)

                    AddBodyPart(
                        Data,
                        Object
                    )
                end)

        -----------------------------------------------------
        -- STREAMING OUT
        -----------------------------------------------------

        Data.Connections.DescendantRemoving =
            Character.DescendantRemoving:
                Connect(function(Object)

                    Data.BodyParts[
                        Object
                    ] =
                        nil
                end)

        -----------------------------------------------------
        -- EQUIPPED TOOL LIFECYCLE
        -----------------------------------------------------

        Data.Connections.ChildAdded =
            Character.ChildAdded:
                Connect(function(Object)

                    if
                        Object:IsA(
                            "Tool"
                        )
                    then

                        task.defer(
                            RefreshWeapon,
                            Data
                        )
                    end
                end)

        Data.Connections.ChildRemoved =
            Character.ChildRemoved:
                Connect(function(Object)

                    if
                        Object == Data.WeaponObject
                        or Object:IsA(
                            "Tool"
                        )
                    then

                        task.defer(
                            RefreshWeapon,
                            Data
                        )
                    end
                end)
    end

    local function UnregisterEntity(
        Character
    )

        local Data =
            Entities[Character]

        if not Data then
            return
        end

        for _, Connection
            in pairs(
                Data.Connections
            )
        do

            if Connection then

                pcall(
                    Connection.Disconnect,
                    Connection
                )
            end
        end

        table.clear(
            Data.Connections
        )

        if Data.Visuals then

            if Data.Visuals.Box then

                pcall(
                    Data.Visuals.Box.Destroy,
                    Data.Visuals.Box
                )
            end

            for _, Name
                in ipairs({
                    "Name",
                    "Health",
                    "Weapon",
                    "Distance",
                })
            do

                local Object =
                    Data.Visuals[Name]

                if Object then

                    pcall(
                        Object.Destroy,
                        Object
                    )
                end
            end
        end

        Entities[Character] =
            nil
    end

    ---------------------------------------------------------
    -- PLAYER TRACKER
    ---------------------------------------------------------

    local function DisconnectPlayer(
        Player
    )

        local Set =
            PlayerConnections[Player]

        if Set then

            for _, Connection
                in pairs(Set)
            do

                if Connection then

                    pcall(
                        Connection.Disconnect,
                        Connection
                    )
                end
            end

            PlayerConnections[Player] =
                nil
        end

        -----------------------------------------------------
        -- SAFETY CLEANUP
        -----------------------------------------------------

        local RemoveQueue = {}

        for Character, Data
            in pairs(
                Entities
            )
        do

            if Data.Player == Player then

                table.insert(
                    RemoveQueue,
                    Character
                )
            end
        end

        for _, Character
            in ipairs(
                RemoveQueue
            )
        do

            UnregisterEntity(
                Character
            )
        end
    end

    local function TrackPlayer(
        Player
    )

        if
            Destroyed
            or not Player
            or Player == LocalPlayer
            or PlayerConnections[Player]
        then
            return
        end

        local Set = {}

        PlayerConnections[Player] =
            Set

        Set.CharacterAdded =
            Player.CharacterAdded:
                Connect(function(Character)

                    RegisterEntity(
                        Player,
                        Character
                    )
                end)

        Set.CharacterRemoving =
            Player.CharacterRemoving:
                Connect(function(Character)

                    UnregisterEntity(
                        Character
                    )
                end)

        if Player.Character then

            RegisterEntity(
                Player,
                Player.Character
            )
        end
    end

    ---------------------------------------------------------
    -- TEAM CHECK
    ---------------------------------------------------------

    local function IsTeammate(
        Data
    )

        if not Settings.TeamCheck then
            return false
        end

        local Player =
            Data.Player

        if
            not Player
            or not LocalPlayer.Team
            or not Player.Team
        then
            return false
        end

        return
            Player.Team
            == LocalPlayer.Team
    end

    ---------------------------------------------------------
    -- HEALTH COLOR
    ---------------------------------------------------------

    local function GetHealthColor(
        Humanoid
    )

        if
            not Settings.DynamicHealthColor
        then

            return
                Settings.TextColor
                or Color3.new(
                    1,
                    1,
                    1
                )
        end

        local MaxHealth =
            math.max(
                Humanoid.MaxHealth,
                1
            )

        local Ratio =
            math.clamp(
                Humanoid.Health
                / MaxHealth,
                0,
                1
            )

        return
            Color3.fromHSV(
                Ratio * 0.33,
                0.85,
                1
            )
    end

    ---------------------------------------------------------
    -- VISIBILITY CHECK
    ---------------------------------------------------------

    local function FindVisibilityTarget(
        Character,
        Root
    )

        for _, Name
            in ipairs({
                "Head",
                "UpperTorso",
                "LowerTorso",
            })
        do

            local Part =
                Character:
                    FindFirstChild(
                        Name
                    )

            if
                Part
                and Part:IsA(
                    "BasePart"
                )
            then
                return Part
            end
        end

        return Root
    end

    local function IsEntityVisible(
        Data,
        Camera,
        Root
    )

        if
            not Settings.VisibilityCheck
        then
            return true
        end

        local Now =
            os.clock()

        if
            Now
            - Data.LastVisibilityCheck
            < VISIBILITY_INTERVAL
        then

            return
                Data.LastVisibility
        end

        Data.LastVisibilityCheck =
            Now

        local Character =
            Data.Character

        local Target =
            FindVisibilityTarget(
                Character,
                Root
            )

        if
            not Target
            or not Target:IsA(
                "BasePart"
            )
        then

            Data.LastVisibility =
                false

            return false
        end

        local Ignore = {
            Camera,
        }

        if LocalPlayer.Character then

            table.insert(
                Ignore,
                LocalPlayer.Character
            )
        end

        VisibilityParams.FilterDescendantsInstances =
            Ignore

        local Origin =
            Camera.CFrame.Position

        local Direction =
            Target.Position
            - Origin

        local Result =
            Workspace:
                Raycast(
                    Origin,
                    Direction,
                    VisibilityParams
                )

        local Visible =
            not Result
            or (
                Result.Instance
                and Result.Instance:
                    IsDescendantOf(
                        Character
                    )
            )

        Data.LastVisibility =
            Visible

        return Visible
    end

    ---------------------------------------------------------
    -- SCREEN BOUNDS
    ---------------------------------------------------------

    local function ProjectPart(
        Part,
        Camera,
        Bounds
    )

        local Half =
            Part.Size / 2

        local X, Y, Z =
            Half.X,
            Half.Y,
            Half.Z

        local PartCFrame =
            Part.CFrame

        local function AddCorner(
            OffsetX,
            OffsetY,
            OffsetZ
        )

            local WorldPosition =
                PartCFrame:
                    PointToWorldSpace(
                        Vector3.new(
                            OffsetX,
                            OffsetY,
                            OffsetZ
                        )
                    )

            local ScreenPosition =
                Camera:
                    WorldToViewportPoint(
                        WorldPosition
                    )

            if
                ScreenPosition.Z
                <= 0.05
            then
                return
            end

            Bounds.HasPoint =
                true

            Bounds.MinX =
                math.min(
                    Bounds.MinX,
                    ScreenPosition.X
                )

            Bounds.MinY =
                math.min(
                    Bounds.MinY,
                    ScreenPosition.Y
                )

            Bounds.MaxX =
                math.max(
                    Bounds.MaxX,
                    ScreenPosition.X
                )

            Bounds.MaxY =
                math.max(
                    Bounds.MaxY,
                    ScreenPosition.Y
                )
        end

        AddCorner(-X, -Y, -Z)
        AddCorner(-X, -Y,  Z)

        AddCorner(-X,  Y, -Z)
        AddCorner(-X,  Y,  Z)

        AddCorner( X, -Y, -Z)
        AddCorner( X, -Y,  Z)

        AddCorner( X,  Y, -Z)
        AddCorner( X,  Y,  Z)
    end

    local function GetCharacterBounds(
        Data,
        Camera,
        Root
    )

        local RootScreen =
            Camera:
                WorldToViewportPoint(
                    Root.Position
                )

        if
            RootScreen.Z
            <= 0.05
        then
            return nil
        end

        local Bounds = {
            MinX = math.huge,
            MinY = math.huge,

            MaxX = -math.huge,
            MaxY = -math.huge,

            HasPoint = false,
        }

        for Part
            in pairs(
                Data.BodyParts
            )
        do

            if
                Part.Parent
                and Part:
                    IsDescendantOf(
                        Data.Character
                    )
            then

                ProjectPart(
                    Part,
                    Camera,
                    Bounds
                )
            else

                Data.BodyParts[
                    Part
                ] =
                    nil
            end
        end

        if not Bounds.HasPoint then
            return nil
        end

        local Viewport =
            Camera.ViewportSize

        if
            Bounds.MaxX < 0
            or Bounds.MinX > Viewport.X
            or Bounds.MaxY < 0
            or Bounds.MinY > Viewport.Y
        then
            return nil
        end

        local Padding =
            tonumber(
                Settings.BoxPadding
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

        if
            Width <= 2
            or Height <= 2
        then
            return nil
        end

        return {
            X = X,
            Y = Y,

            Width = Width,
            Height = Height,

            CenterX =
                X
                + Width / 2,

            CenterY =
                Y
                + Height / 2,
        }
    end

    ---------------------------------------------------------
    -- CORNER BOX
    ---------------------------------------------------------

    local function UpdateCornerBox(
        Visuals,
        Width,
        Height,
        Color
    )

        local Thickness =
            math.max(
                1,
                tonumber(
                    Settings.BoxThickness
                )
                or 1
            )

        local Ratio =
            math.clamp(
                tonumber(
                    Settings.CornerRatio
                )
                or 0.25,
                0.05,
                0.50
            )

        local Corner =
            math.max(
                5,
                math.floor(
                    math.min(
                        Width,
                        Height
                    )
                    * Ratio
                )
            )

        Corner =
            math.min(
                Corner,
                Width / 2,
                Height / 2
            )

        local C =
            Visuals.Corners

        for _, Line
            in ipairs(C)
        do

            Line.BackgroundColor3 =
                Color
        end

        -- TOP LEFT
        C[1].Position = UDim2.fromOffset(0, 0)
        C[1].Size = UDim2.fromOffset(Corner, Thickness)

        C[2].Position = UDim2.fromOffset(0, 0)
        C[2].Size = UDim2.fromOffset(Thickness, Corner)

        -- TOP RIGHT
        C[3].Position = UDim2.fromOffset(Width - Corner, 0)
        C[3].Size = UDim2.fromOffset(Corner, Thickness)

        C[4].Position = UDim2.fromOffset(Width - Thickness, 0)
        C[4].Size = UDim2.fromOffset(Thickness, Corner)

        -- BOTTOM LEFT
        C[5].Position = UDim2.fromOffset(0, Height - Thickness)
        C[5].Size = UDim2.fromOffset(Corner, Thickness)

        C[6].Position = UDim2.fromOffset(0, Height - Corner)
        C[6].Size = UDim2.fromOffset(Thickness, Corner)

        -- BOTTOM RIGHT
        C[7].Position = UDim2.fromOffset(Width - Corner, Height - Thickness)
        C[7].Size = UDim2.fromOffset(Corner, Thickness)

        C[8].Position = UDim2.fromOffset(Width - Thickness, Height - Corner)
        C[8].Size = UDim2.fromOffset(Thickness, Corner)
    end

    ---------------------------------------------------------
    -- UPDATE ENTITY
    ---------------------------------------------------------

    local function UpdateEntity(
        Data,
        Camera
    )

        if not Settings.Enabled then

            HideEntity(
                Data
            )

            return
        end

        local Player =
            Data.Player

        local Character =
            Data.Character

        if
            not Player
            or not Character
            or Player.Character ~= Character
            or not Character.Parent
        then

            HideEntity(
                Data
            )

            return
        end

        -----------------------------------------------------
        -- TEAM
        -----------------------------------------------------

        if IsTeammate(Data) then

            HideEntity(
                Data
            )

            return
        end

        -----------------------------------------------------
        -- STREAMING-AWARE ROOT / HUMANOID
        -----------------------------------------------------

        local Root =
            Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )

        local Humanoid =
            Character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        -- With StreamingEnabled the Character can stay alive
        -- while its physical body is temporarily absent.
        if
            not Root
            or not Root:IsA(
                "BasePart"
            )
            or not Humanoid
            or Humanoid.Health <= 0
        then

            HideEntity(
                Data
            )

            return
        end

        -----------------------------------------------------
        -- WEAPON REFRESH FALLBACK
        -----------------------------------------------------

        if
            (
                not Data.WeaponObject
                or Data.WeaponObject.Parent
                    ~= Character
            )
            and (
                os.clock()
                - Data.LastWeaponCheck
            ) >= 0.50
        then

            RefreshWeapon(
                Data
            )
        end

        -----------------------------------------------------
        -- DISTANCE
        -----------------------------------------------------

        local Distance =
            (
                Root.Position
                - Camera.CFrame.Position
            ).Magnitude

        local MaxDistance =
            tonumber(
                Settings.MaxDistance
            )
            or 1000

        if Distance > MaxDistance then

            HideEntity(
                Data
            )

            return
        end

        -----------------------------------------------------
        -- BOUNDS
        -----------------------------------------------------

        local Bounds =
            GetCharacterBounds(
                Data,
                Camera,
                Root
            )

        if not Bounds then

            HideEntity(
                Data
            )

            return
        end

        -----------------------------------------------------
        -- VISIBILITY
        -----------------------------------------------------

        local Visible =
            IsEntityVisible(
                Data,
                Camera,
                Root
            )

        local VisibleBoxColor =
            Settings.VisibleColor
            or Color3.fromRGB(
                90,
                255,
                130
            )

        local HiddenBoxColor =
            Settings.HiddenColor
            or Color3.fromRGB(
                255,
                90,
                90
            )

        local BoxColor =
            VisibleBoxColor

        if
            Settings.VisibilityCheck
            and not Visible
        then

            BoxColor =
                HiddenBoxColor
        end

        -----------------------------------------------------
        -- VISUALS
        -----------------------------------------------------

        local Visuals =
            Data.Visuals

        Visuals.Stroke.Color =
            BoxColor

        Visuals.Stroke.Thickness =
            tonumber(
                Settings.BoxThickness
            )
            or 1

        local BoxWidth =
            math.floor(
                Bounds.Width
            )

        local BoxHeight =
            math.floor(
                Bounds.Height
            )

        Visuals.Box.Position =
            UDim2.fromOffset(
                math.floor(
                    Bounds.X
                ),
                math.floor(
                    Bounds.Y
                )
            )

        Visuals.Box.Size =
            UDim2.fromOffset(
                BoxWidth,
                BoxHeight
            )

        local BoxEnabled =
            Settings.Box
            == true

        local CornerStyle =
            (
                Settings.BoxStyle
                or "Corner"
            )
            == "Corner"

        Visuals.Box.Visible =
            BoxEnabled

        Visuals.Stroke.Enabled =
            BoxEnabled
            and not CornerStyle

        for _, Line
            in ipairs(
                Visuals.Corners
            )
        do

            Line.Visible =
                BoxEnabled
                and CornerStyle
        end

        if
            BoxEnabled
            and CornerStyle
        then

            UpdateCornerBox(
                Visuals,
                BoxWidth,
                BoxHeight,
                BoxColor
            )
        end

        -----------------------------------------------------
        -- TEXT COLORS
        -----------------------------------------------------

        local TextColor =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        Visuals.Name.TextColor3 =
            TextColor

        Visuals.Weapon.TextColor3 =
            TextColor

        Visuals.Distance.TextColor3 =
            TextColor

        Visuals.Health.TextColor3 =
            GetHealthColor(
                Humanoid
            )

        -----------------------------------------------------
        -- NAME
        -----------------------------------------------------

        Visuals.Name.Text =
            Player.Name

        Visuals.Name.Position =
            UDim2.fromOffset(
                Bounds.CenterX,
                Bounds.Y - 12
            )

        Visuals.Name.Visible =
            Settings.Name
            == true

        -----------------------------------------------------
        -- BOTTOM TEXT STACK
        -----------------------------------------------------

        local NextY =
            Bounds.Y
            + Bounds.Height
            + 10

        local function PlaceBottomText(
            Label,
            ShouldShow,
            Text
        )

            Label.Visible =
                ShouldShow

            if not ShouldShow then
                return
            end

            Label.Text =
                Text

            Label.Position =
                UDim2.fromOffset(
                    Bounds.CenterX,
                    NextY
                )

            NextY += 17
        end

        PlaceBottomText(
            Visuals.Health,
            Settings.Health == true,
            string.format(
                "%d/%d HP",
                math.floor(
                    Humanoid.Health
                ),
                math.floor(
                    Humanoid.MaxHealth
                )
            )
        )

        local WeaponName =
            Data.WeaponName

        PlaceBottomText(
            Visuals.Weapon,
            Settings.Weapon == true
                and type(
                    WeaponName
                ) == "string"
                and WeaponName ~= "",
            WeaponName or ""
        )

        PlaceBottomText(
            Visuals.Distance,
            Settings.Distance == true,
            string.format(
                "%.0f studs",
                Distance
            )
        )
    end

    ---------------------------------------------------------
    -- TRACK EXISTING PLAYERS
    ---------------------------------------------------------

    for _, Player
        in ipairs(
            Players:
                GetPlayers()
        )
    do

        TrackPlayer(
            Player
        )
    end

    ---------------------------------------------------------
    -- PLAYER EVENTS
    ---------------------------------------------------------

    Connections.PlayerAdded =
        Players.PlayerAdded:
            Connect(function(Player)

                TrackPlayer(
                    Player
                )
            end)

    Connections.PlayerRemoving =
        Players.PlayerRemoving:
            Connect(function(Player)

                DisconnectPlayer(
                    Player
                )
            end)

    ---------------------------------------------------------
    -- RENDER
    ---------------------------------------------------------

    Connections.Render =
        RunService.RenderStepped:
            Connect(function(DeltaTime)

                if Destroyed then
                    return
                end

                UpdateAccumulator +=
                    DeltaTime

                if
                    UpdateAccumulator
                    < UPDATE_RATE
                then
                    return
                end

                UpdateAccumulator =
                    UpdateAccumulator
                    % UPDATE_RATE

                local Camera =
                    Workspace.CurrentCamera

                if not Camera then
                    return
                end

                if not Settings.Enabled then

                    for _, Data
                        in pairs(
                            Entities
                        )
                    do

                        HideEntity(
                            Data
                        )
                    end

                    return
                end

                for _, Data
                    in pairs(
                        Entities
                    )
                do

                    UpdateEntity(
                        Data,
                        Camera
                    )
                end
            end)

    ---------------------------------------------------------
    -- CONTROLLER
    ---------------------------------------------------------

    local Controller = {}

    function Controller.Toggle(Value)

        Settings.Enabled =
            Value == true
    end

    function Controller.GetEntityCount()

        local Count = 0

        for _
            in pairs(
                Entities
            )
        do

            Count += 1
        end

        return Count
    end

    function Controller.GetLocalEntity()

        return
            LocalPlayer.Character
    end

    function Controller.Destroy()

        if Destroyed then
            return
        end

        Destroyed =
            true

        -----------------------------------------------------
        -- GLOBAL CONNECTIONS
        -----------------------------------------------------

        for _, Connection
            in pairs(
                Connections
            )
        do

            if Connection then

                pcall(
                    Connection.Disconnect,
                    Connection
                )
            end
        end

        table.clear(
            Connections
        )

        -----------------------------------------------------
        -- PLAYER CONNECTIONS
        -----------------------------------------------------

        local PlayerQueue = {}

        for Player
            in pairs(
                PlayerConnections
            )
        do

            table.insert(
                PlayerQueue,
                Player
            )
        end

        for _, Player
            in ipairs(
                PlayerQueue
            )
        do

            DisconnectPlayer(
                Player
            )
        end

        table.clear(
            PlayerConnections
        )

        -----------------------------------------------------
        -- ENTITY SAFETY CLEANUP
        -----------------------------------------------------

        local EntityQueue = {}

        for Character
            in pairs(
                Entities
            )
        do

            table.insert(
                EntityQueue,
                Character
            )
        end

        for _, Character
            in ipairs(
                EntityQueue
            )
        do

            UnregisterEntity(
                Character
            )
        end

        -----------------------------------------------------
        -- GUI
        -----------------------------------------------------

        if ScreenGui then

            pcall(
                ScreenGui.Destroy,
                ScreenGui
            )
        end
    end

    return Controller
end

return ESP
