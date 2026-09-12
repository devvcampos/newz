local AdvancedESP = {}

function AdvancedESP.Init(Config)
    local Players =
        game:GetService("Players")

    local RunService =
        game:GetService("RunService")

    local Workspace =
        game:GetService("Workspace")

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "AdvancedESP precisa ser inicializado no cliente"
    )

    local Settings =
        Config.ESP
        or {}

    local Runtime =
        Config.Runtime
        or {}

    local UpdateFrequency =
        math.clamp(
            tonumber(
                Runtime.UpdateFrequency
            )
            or 30,
            1,
            120
        )

    local UpdateInterval =
        1 / UpdateFrequency

    local ParentGui =
        LocalPlayer:WaitForChild("PlayerGui")

    local OldGui =
        ParentGui:
            FindFirstChild(
                "NEWZ_AdvancedESP"
            )

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui =
        Instance.new(
            "ScreenGui"
        )

    ScreenGui.Name =
        "NEWZ_AdvancedESP"

    ScreenGui.ResetOnSpawn =
        false

    ScreenGui.IgnoreGuiInset =
        true

    ScreenGui.DisplayOrder =
        997

    ScreenGui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    ScreenGui.Parent =
        ParentGui

    local Destroyed = false
    local Accumulator = 0

    local DataByPlayer = {}
    local Connections = {}

    local VisibilityParams =
        RaycastParams.new()

    VisibilityParams.FilterType =
        Enum.RaycastFilterType.Exclude

    VisibilityParams.IgnoreWater =
        true

    local SkeletonPairs = {
        -- R15
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},

        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},

        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},

        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},

        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},

        -- R6 fallback
        {"Head", "Torso"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    }

    local function NewFrame(
        Parent,
        ZIndex
    )
        local Frame =
            Instance.new(
                "Frame"
            )

        Frame.BackgroundTransparency =
            0

        Frame.BorderSizePixel =
            0

        Frame.Visible =
            false

        Frame.ZIndex =
            ZIndex
            or 20

        Frame.Parent =
            Parent

        return Frame
    end

    local function NewText(
        Parent,
        ZIndex
    )
        local Label =
            Instance.new(
                "TextLabel"
            )

        Label.BackgroundTransparency =
            1

        Label.Size =
            UDim2.fromOffset(
                220,
                18
            )

        Label.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        Label.Font =
            Enum.Font.Gotham

        Label.TextSize =
            13

        Label.TextColor3 =
            Color3.new(
                1,
                1,
                1
            )

        Label.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )

        Label.TextStrokeTransparency =
            0.25

        Label.Visible =
            false

        Label.ZIndex =
            ZIndex
            or 22

        Label.Parent =
            Parent

        return Label
    end

    local function CreateData(Player)
        local Root =
            Instance.new(
                "Folder"
            )

        Root.Name =
            "Player_"
            .. tostring(
                Player.UserId
            )

        Root.Parent =
            ScreenGui

        local OutlineBox =
            NewFrame(
                Root,
                18
            )

        OutlineBox.BackgroundTransparency =
            1

        local OutlineStroke =
            Instance.new(
                "UIStroke"
            )

        OutlineStroke.Color =
            Color3.new(
                0,
                0,
                0
            )

        OutlineStroke.Thickness =
            3

        OutlineStroke.LineJoinMode =
            Enum.LineJoinMode.Miter

        OutlineStroke.Parent =
            OutlineBox

        local HealthBG =
            NewFrame(
                Root,
                21
            )

        local HealthFill =
            NewFrame(
                HealthBG,
                22
            )

        HealthFill.AnchorPoint =
            Vector2.new(
                0,
                1
            )

        HealthFill.Position =
            UDim2.fromScale(
                0,
                1
            )

        local HealthText =
            NewText(
                Root,
                23
            )

        local FlagText =
            NewText(
                Root,
                23
            )

        local ArrowText =
            NewText(
                Root,
                30
            )

        ArrowText.Text =
            "▲"

        ArrowText.Size =
            UDim2.fromOffset(
                28,
                28
            )

        ArrowText.TextSize =
            24

        local NameText =
            NewText(
                Root,
                23
            )

        local DistanceText =
            NewText(
                Root,
                23
            )

        return {
            Player =
                Player,

            Root =
                Root,

            Character =
                nil,

            Highlight =
                nil,

            OutlineBox =
                OutlineBox,

            OutlineStroke =
                OutlineStroke,

            HealthBG =
                HealthBG,

            HealthFill =
                HealthFill,

            HealthText =
                HealthText,

            FlagText =
                FlagText,

            ArrowText =
                ArrowText,

            NameText =
                NameText,

            DistanceText =
                DistanceText,

            SkeletonLines =
                {},
        }
    end

    local function GetData(Player)
        local Data =
            DataByPlayer[
                Player
            ]

        if Data then
            return Data
        end

        Data =
            CreateData(
                Player
            )

        DataByPlayer[
            Player
        ] =
            Data

        return Data
    end

    local function DestroyHighlight(Data)
        if Data.Highlight then
            pcall(
                Data.Highlight.Destroy,
                Data.Highlight
            )

            Data.Highlight =
                nil
        end
    end

    local function HideSkeleton(Data)
        for _, Line
            in ipairs(
                Data.SkeletonLines
            )
        do
            Line.Visible =
                false
        end
    end

    local function Hide2D(Data)
        Data.OutlineBox.Visible =
            false

        Data.HealthBG.Visible =
            false

        Data.HealthFill.Visible =
            false

        Data.HealthText.Visible =
            false

        Data.FlagText.Visible =
            false

        Data.ArrowText.Visible =
            false

        Data.NameText.Visible =
            false

        Data.DistanceText.Visible =
            false

        HideSkeleton(
            Data
        )
    end

    local function HideAll(Data)
        Hide2D(
            Data
        )

        if Data.Highlight then
            Data.Highlight.Enabled =
                false
        end
    end

    local function RemoveData(Player)
        local Data =
            DataByPlayer[
                Player
            ]

        if not Data then
            return
        end

        DestroyHighlight(
            Data
        )

        if Data.Root then
            pcall(
                Data.Root.Destroy,
                Data.Root
            )
        end

        DataByPlayer[
            Player
        ] =
            nil
    end

    local function IsTeammate(Player)
        if
            Settings.TeamCheck
            ~= true
        then
            return false
        end

        if
            not LocalPlayer.Team
            or not Player.Team
        then
            return false
        end

        return
            Player.Team
            == LocalPlayer.Team
    end

    local function IsVisible(
        Character,
        TargetPart,
        Camera
    )
        if
            not TargetPart
            or not Camera
        then
            return false
        end

        local Ignore = {
            Camera,
        }

        if LocalPlayer.Character then
            Ignore[
                #Ignore + 1
            ] =
                LocalPlayer.Character
        end

        VisibilityParams
            .FilterDescendantsInstances =
                Ignore

        local Origin =
            Camera.CFrame.Position

        local Direction =
            TargetPart.Position
            - Origin

        local Result =
            Workspace:Raycast(
                Origin,
                Direction,
                VisibilityParams
            )

        return
            not Result
            or (
                Result.Instance
                and Result.Instance:
                    IsDescendantOf(
                        Character
                    )
            )
    end

    local function GetBounds(
        Character,
        Camera
    )
        local Success,
            Pivot,
            Size =
                pcall(
                    Character.GetBoundingBox,
                    Character
                )

        if not Success then
            return nil
        end

        local Half =
            Size * 0.5

        local MinX =
            math.huge

        local MinY =
            math.huge

        local MaxX =
            -math.huge

        local MaxY =
            -math.huge

        local SawPoint =
            false

        for X = -1, 1, 2 do
            for Y = -1, 1, 2 do
                for Z = -1, 1, 2 do
                    local World =
                        (
                            Pivot
                            * CFrame.new(
                                Half.X * X,
                                Half.Y * Y,
                                Half.Z * Z
                            )
                        ).Position

                    local Point =
                        Camera:
                            WorldToViewportPoint(
                                World
                            )

                    if Point.Z > 0 then
                        SawPoint =
                            true

                        MinX =
                            math.min(
                                MinX,
                                Point.X
                            )

                        MinY =
                            math.min(
                                MinY,
                                Point.Y
                            )

                        MaxX =
                            math.max(
                                MaxX,
                                Point.X
                            )

                        MaxY =
                            math.max(
                                MaxY,
                                Point.Y
                            )
                    end
                end
            end
        end

        if not SawPoint then
            return nil
        end

        return {
            X =
                MinX,

            Y =
                MinY,

            Width =
                math.max(
                    1,
                    MaxX - MinX
                ),

            Height =
                math.max(
                    1,
                    MaxY - MinY
                ),

            CenterX =
                (
                    MinX + MaxX
                ) * 0.5,

            CenterY =
                (
                    MinY + MaxY
                ) * 0.5,
        }
    end

    local function UpdateLine(
        Line,
        A,
        B,
        Thickness,
        Color
    )
        local Delta =
            B - A

        local Length =
            Delta.Magnitude

        if Length < 1 then
            Line.Visible =
                false

            return
        end

        Line.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        Line.Position =
            UDim2.fromOffset(
                (
                    A.X + B.X
                ) * 0.5,
                (
                    A.Y + B.Y
                ) * 0.5
            )

        Line.Size =
            UDim2.fromOffset(
                Length,
                math.max(
                    1,
                    Thickness
                )
            )

        Line.Rotation =
            math.deg(
                math.atan2(
                    Delta.Y,
                    Delta.X
                )
            )

        Line.BackgroundColor3 =
            Color

        Line.Visible =
            true
    end

    local function EnsureSkeletonLine(
        Data,
        Index
    )
        local Line =
            Data.SkeletonLines[
                Index
            ]

        if Line then
            return Line
        end

        Line =
            NewFrame(
                Data.Root,
                21
            )

        Data.SkeletonLines[
            Index
        ] =
            Line

        return Line
    end

    local function UpdateSkeleton(
        Data,
        Character,
        Camera
    )
        local Skeleton =
            Settings.Skeleton
            or {}

        if
            Skeleton.Enabled
            ~= true
        then
            HideSkeleton(
                Data
            )

            return
        end

        local Color =
            Skeleton.Color
            or Color3.new(
                1,
                1,
                1
            )

        local Thickness =
            tonumber(
                Skeleton.Thickness
            )
            or 1

        local Used =
            0

        for _, Pair
            in ipairs(
                SkeletonPairs
            )
        do
            local APart =
                Character:
                    FindFirstChild(
                        Pair[1]
                    )

            local BPart =
                Character:
                    FindFirstChild(
                        Pair[2]
                    )

            if
                APart
                and BPart
                and APart:IsA(
                    "BasePart"
                )
                and BPart:IsA(
                    "BasePart"
                )
            then
                local A,
                    AOnScreen =
                        Camera:
                            WorldToViewportPoint(
                                APart.Position
                            )

                local B,
                    BOnScreen =
                        Camera:
                            WorldToViewportPoint(
                                BPart.Position
                            )

                if
                    A.Z > 0
                    and B.Z > 0
                    and (
                        AOnScreen
                        or BOnScreen
                    )
                then
                    Used += 1

                    local Line =
                        EnsureSkeletonLine(
                            Data,
                            Used
                        )

                    UpdateLine(
                        Line,
                        Vector2.new(
                            A.X,
                            A.Y
                        ),
                        Vector2.new(
                            B.X,
                            B.Y
                        ),
                        Thickness,
                        Color
                    )
                end
            end
        end

        for Index =
            Used + 1,
            #Data.SkeletonLines
        do
            Data.SkeletonLines[
                Index
            ].Visible =
                false
        end
    end

    local function GetHealthColor(
        Humanoid
    )
        local HealthSettings =
            Settings.HealthBar
            or {}

        if
            HealthSettings.DynamicColor
            == false
        then
            return
                HealthSettings.Color
                or Color3.fromRGB(
                    90,
                    255,
                    130
                )
        end

        local Ratio =
            math.clamp(
                Humanoid.Health
                / math.max(
                    Humanoid.MaxHealth,
                    1
                ),
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

    local function UpdateHealthBar(
        Data,
        Bounds,
        Humanoid
    )
        local HealthSettings =
            Settings.HealthBar
            or {}

        if
            HealthSettings.Enabled
            ~= true
        then
            Data.HealthBG.Visible =
                false

            Data.HealthFill.Visible =
                false

            Data.HealthText.Visible =
                false

            return
        end

        local Width =
            math.max(
                2,
                tonumber(
                    HealthSettings.Width
                )
                or 3
            )

        local PositionName =
            tostring(
                HealthSettings.Position
                or "Left"
            )

        local X

        if
            PositionName
            == "Right"
        then
            X =
                Bounds.X
                + Bounds.Width
                + 4
        else
            X =
                Bounds.X
                - Width
                - 4
        end

        Data.HealthBG.Position =
            UDim2.fromOffset(
                X,
                Bounds.Y
            )

        Data.HealthBG.Size =
            UDim2.fromOffset(
                Width,
                Bounds.Height
            )

        Data.HealthBG.BackgroundColor3 =
            HealthSettings.BackgroundColor
            or Color3.fromRGB(
                12,
                12,
                12
            )

        Data.HealthBG.Visible =
            true

        local Ratio =
            math.clamp(
                Humanoid.Health
                / math.max(
                    Humanoid.MaxHealth,
                    1
                ),
                0,
                1
            )

        Data.HealthFill.Position =
            UDim2.fromScale(
                0,
                1
            )

        Data.HealthFill.Size =
            UDim2.new(
                1,
                0,
                Ratio,
                0
            )

        Data.HealthFill.BackgroundColor3 =
            GetHealthColor(
                Humanoid
            )

        Data.HealthFill.Visible =
            true

        if
            HealthSettings.ShowText
            == true
        then
            Data.HealthText.Text =
                string.format(
                    "%d%%",
                    math.floor(
                        Ratio * 100
                        + 0.5
                    )
                )

            Data.HealthText.Position =
                UDim2.fromOffset(
                    X
                    + Width * 0.5,
                    Bounds.Y - 10
                )

            Data.HealthText.Visible =
                true
        else
            Data.HealthText.Visible =
                false
        end
    end

    local function UpdateFlags(
        Data,
        Bounds,
        Humanoid
    )
        local FlagSettings =
            Settings.Flags
            or {}

        if
            FlagSettings.Enabled
            ~= true
        then
            Data.FlagText.Visible =
                false

            return
        end

        local State =
            Humanoid:
                GetState()

        local Label =
            "Idle"

        if
            State
                == Enum.HumanoidStateType.Jumping
            or State
                == Enum.HumanoidStateType.Freefall
        then
            Label =
                "Jumping"

        elseif
            Humanoid.MoveDirection.Magnitude
            > 0.05
        then
            Label =
                "Moving"
        end

        local Options =
            FlagSettings.Options
            or {}

        if
            Options[Label]
            == false
        then
            Data.FlagText.Visible =
                false

            return
        end

        Data.FlagText.Text =
            Label

        Data.FlagText.TextColor3 =
            FlagSettings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        Data.FlagText.Position =
            UDim2.fromOffset(
                Bounds.X
                + Bounds.Width
                + 34,
                Bounds.Y
                + 8
            )

        Data.FlagText.Visible =
            true
    end

    local function UpdateAdvancedText(
        Data,
        Bounds,
        Player,
        Distance
    )
        local TextSettings =
            Settings.AdvancedText
            or {}

        if
            TextSettings.Enabled
            ~= true
        then
            Data.NameText.Visible =
                false

            Data.DistanceText.Visible =
                false

            return
        end

        local Gap =
            tonumber(
                TextSettings.Gap
            )
            or 2

        local TextSize =
            math.max(
                8,
                tonumber(
                    TextSettings.TextSize
                )
                or 13
            )

        Data.NameText.TextSize =
            TextSize

        Data.DistanceText.TextSize =
            TextSize

        local StrokeTransparency =
            (
                TextSettings.TextOutline
                ~= false
            )
            and 0.25
            or 1

        Data.NameText.TextStrokeTransparency =
            StrokeTransparency

        Data.DistanceText.TextStrokeTransparency =
            StrokeTransparency

        local TextColor =
            Settings.TextColor
            or Color3.new(
                1,
                1,
                1
            )

        Data.NameText.TextColor3 =
            TextColor

        Data.DistanceText.TextColor3 =
            TextColor

        local PositionName =
            tostring(
                TextSettings.Position
                or "Bottom"
            )

        local BaseX =
            Bounds.CenterX

        local BaseY =
            Bounds.Y
            + Bounds.Height
            + 12

        if
            PositionName
            == "Top"
        then
            BaseY =
                Bounds.Y
                - 12

        elseif
            PositionName
            == "Side"
        then
            BaseX =
                Bounds.X
                + Bounds.Width
                + 62

            BaseY =
                Bounds.Y
                + 18
        end

        local ShowName =
            TextSettings.Name
            ~= false

        Data.NameText.Visible =
            ShowName

        if ShowName then
            Data.NameText.Text =
                Player.Name

            Data.NameText.Position =
                UDim2.fromOffset(
                    BaseX,
                    BaseY
                )
        end

        local ShowDistance =
            TextSettings.Distance
            ~= false

        Data.DistanceText.Visible =
            ShowDistance

        if ShowDistance then
            Data.DistanceText.Text =
                tostring(
                    math.floor(
                        Distance + 0.5
                    )
                )
                .. " studs"

            local Offset =
                ShowName
                and (
                    TextSize
                    + Gap
                )
                or 0

            if
                PositionName
                == "Top"
            then
                Offset =
                    -Offset
            end

            Data.DistanceText.Position =
                UDim2.fromOffset(
                    BaseX,
                    BaseY + Offset
                )
        end
    end

    local function UpdateOutline(
        Data,
        Bounds
    )
        if
            Settings.Outlines
            ~= true
        then
            Data.OutlineBox.Visible =
                false

            return
        end

        Data.OutlineBox.Position =
            UDim2.fromOffset(
                Bounds.X,
                Bounds.Y
            )

        Data.OutlineBox.Size =
            UDim2.fromOffset(
                Bounds.Width,
                Bounds.Height
            )

        Data.OutlineStroke.Color =
            Settings.OutlineColor
            or Color3.new(
                0,
                0,
                0
            )

        Data.OutlineStroke.Thickness =
            math.max(
                2,
                (
                    tonumber(
                        Settings.BoxThickness
                    )
                    or 1
                )
                + 2
            )

        Data.OutlineBox.Visible =
            true
    end

    local function EnsureHighlight(
        Data,
        Character
    )
        if
            Data.Character
            ~= Character
        then
            DestroyHighlight(
                Data
            )

            Data.Character =
                Character
        end

        if Data.Highlight then
            return Data.Highlight
        end

        local Highlight =
            Instance.new(
                "Highlight"
            )

        Highlight.Name =
            "NEWZ_Chams"

        Highlight.Adornee =
            Character

        Highlight.Enabled =
            false

        Highlight.Parent =
            Character

        Data.Highlight =
            Highlight

        return Highlight
    end

    local function UpdateChams(
        Data,
        Character,
        Visible
    )
        local Chams =
            Settings.Chams
            or {}

        if
            Chams.Enabled
            ~= true
        then
            if Data.Highlight then
                Data.Highlight.Enabled =
                    false
            end

            return
        end

        local Highlight =
            EnsureHighlight(
                Data,
                Character
            )

        if
            Chams.VisibleCheck
            == true
            and not Visible
        then
            Highlight.Enabled =
                false

            return
        end

        Highlight.FillColor =
            Chams.FillColor
            or Color3.fromRGB(
                85,
                170,
                255
            )

        Highlight.FillTransparency =
            math.clamp(
                tonumber(
                    Chams.FillTransparency
                )
                or 0.55,
                0,
                1
            )

        Highlight.OutlineColor =
            Chams.OutlineColor
            or Color3.new(
                1,
                1,
                1
            )

        Highlight.OutlineTransparency =
            math.clamp(
                tonumber(
                    Chams.OutlineTransparency
                )
                or 0,
                0,
                1
            )

        Highlight.DepthMode =
            (
                Chams.AlwaysOnTop
                ~= false
            )
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded

        Highlight.Enabled =
            true
    end

    local function UpdateArrow(
        Data,
        RootPart,
        Camera
    )
        local ArrowSettings =
            Settings.OffScreenArrows
            or {}

        if
            ArrowSettings.Enabled
            ~= true
        then
            Data.ArrowText.Visible =
                false

            return
        end

        local Relative =
            Camera.CFrame:
                PointToObjectSpace(
                    RootPart.Position
                )

        local Angle =
            math.atan2(
                Relative.X,
                -Relative.Z
            )

        local Radius =
            math.max(
                30,
                tonumber(
                    ArrowSettings.OrbitRadius
                )
                or 150
            )

        local Center =
            Camera.ViewportSize
            * 0.5

        local X =
            Center.X
            + math.sin(
                Angle
            ) * Radius

        local Y =
            Center.Y
            - math.cos(
                Angle
            ) * Radius

        Data.ArrowText.Position =
            UDim2.fromOffset(
                X,
                Y
            )

        Data.ArrowText.TextSize =
            math.max(
                10,
                tonumber(
                    ArrowSettings.Size
                )
                or 20
            )

        Data.ArrowText.TextColor3 =
            ArrowSettings.Color
            or Color3.new(
                1,
                1,
                1
            )

        Data.ArrowText.TextStrokeColor3 =
            ArrowSettings.OutlineColor
            or Color3.new(
                0,
                0,
                0
            )

        Data.ArrowText.TextStrokeTransparency =
            (
                ArrowSettings.Outline
                ~= false
            )
            and 0.15
            or 1

        Data.ArrowText.Rotation =
            math.deg(
                Angle
            )

        Data.ArrowText.Visible =
            true
    end

    local function HasAnyAdvancedFeature()
        return
            Settings.Outlines
            == true
            or (
                Settings.HealthBar
                and Settings.HealthBar.Enabled
                == true
            )
            or (
                Settings.Skeleton
                and Settings.Skeleton.Enabled
                == true
            )
            or (
                Settings.Flags
                and Settings.Flags.Enabled
                == true
            )
            or (
                Settings.OffScreenArrows
                and Settings.OffScreenArrows.Enabled
                == true
            )
            or (
                Settings.Chams
                and Settings.Chams.Enabled
                == true
            )
            or (
                Settings.AdvancedText
                and Settings.AdvancedText.Enabled
                == true
            )
    end

    local function UpdatePlayer(
        Player,
        Camera
    )
        local Data =
            GetData(
                Player
            )

        if
            Player
            == LocalPlayer
            or Settings.Enabled
            ~= true
            or not HasAnyAdvancedFeature()
            or IsTeammate(
                Player
            )
        then
            HideAll(
                Data
            )

            return
        end

        local Character =
            Player.Character

        local RootPart =
            Character
            and Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )

        local Humanoid =
            Character
            and Character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        local Head =
            Character
            and (
                Character:
                    FindFirstChild(
                        "Head"
                    )
                or RootPart
            )

        if
            not Character
            or not RootPart
            or not Humanoid
            or Humanoid.Health
                <= 0
        then
            HideAll(
                Data
            )

            return
        end

        if
            Data.Character
            ~= Character
        then
            DestroyHighlight(
                Data
            )

            Data.Character =
                Character
        end

        local Distance =
            (
                RootPart.Position
                - Camera.CFrame.Position
            ).Magnitude

        if
            Distance
            > (
                tonumber(
                    Settings.MaxDistance
                )
                or 1000
            )
        then
            HideAll(
                Data
            )

            return
        end

        local RootScreen,
            RootOnScreen =
                Camera:
                    WorldToViewportPoint(
                        RootPart.Position
                    )

        local NeedVisibility =
            Settings.VisibilityCheck
            == true
            or (
                Settings.Chams
                and Settings.Chams.VisibleCheck
                == true
            )

        local Visible =
            true

        if NeedVisibility then
            Visible =
                IsVisible(
                    Character,
                    Head,
                    Camera
                )
        end

        UpdateChams(
            Data,
            Character,
            Visible
        )

        if
            not RootOnScreen
            or RootScreen.Z
                <= 0
        then
            Data.OutlineBox.Visible =
                false

            Data.HealthBG.Visible =
                false

            Data.HealthFill.Visible =
                false

            Data.HealthText.Visible =
                false

            Data.FlagText.Visible =
                false

            Data.NameText.Visible =
                false

            Data.DistanceText.Visible =
                false

            HideSkeleton(
                Data
            )

            UpdateArrow(
                Data,
                RootPart,
                Camera
            )

            return
        end

        Data.ArrowText.Visible =
            false

        local Bounds =
            GetBounds(
                Character,
                Camera
            )

        if not Bounds then
            Hide2D(
                Data
            )

            return
        end

        UpdateOutline(
            Data,
            Bounds
        )

        UpdateHealthBar(
            Data,
            Bounds,
            Humanoid
        )

        UpdateFlags(
            Data,
            Bounds,
            Humanoid
        )

        UpdateAdvancedText(
            Data,
            Bounds,
            Player,
            Distance
        )

        UpdateSkeleton(
            Data,
            Character,
            Camera
        )
    end

    local function Step(
        DeltaTime
    )
        if Destroyed then
            return
        end

        Accumulator +=
            DeltaTime

        if
            Accumulator
            < UpdateInterval
        then
            return
        end

        Accumulator =
            Accumulator
            % UpdateInterval

        local Camera =
            Workspace.CurrentCamera

        if not Camera then
            for _, Data
                in pairs(
                    DataByPlayer
                )
            do
                HideAll(
                    Data
                )
            end

            return
        end

        for _, Player
            in ipairs(
                Players:
                    GetPlayers()
            )
        do
            UpdatePlayer(
                Player,
                Camera
            )
        end
    end

    Connections.PlayerRemoving =
        Players.PlayerRemoving:
            Connect(function(
                Player
            )
                RemoveData(
                    Player
                )
            end)

    Connections.Render =
        RunService.RenderStepped:
            Connect(
                Step
            )

    local Controller = {}

    function Controller.Refresh()
        Accumulator =
            UpdateInterval
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed =
            true

        for _, Connection
            in pairs(
                Connections
            )
        do
            pcall(
                Connection.Disconnect,
                Connection
            )
        end

        table.clear(
            Connections
        )

        for Player
            in pairs(
                DataByPlayer
            )
        do
            RemoveData(
                Player
            )
        end

        if ScreenGui then
            pcall(
                ScreenGui.Destroy,
                ScreenGui
            )
        end
    end

    return Controller
end

return AdvancedESP
