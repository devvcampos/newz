local AimAssist = {}

function AimAssist.Init(Config)
    local Players =
        game:GetService("Players")

    local RunService =
        game:GetService("RunService")

    local UserInputService =
        game:GetService("UserInputService")

    local Workspace =
        game:GetService("Workspace")

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "AimAssist precisa ser inicializado no cliente"
    )

    Config.AimAssist =
        Config.AimAssist
        or {}

    local Settings =
        Config.AimAssist

    local Destroyed = false
    local Active = false
    local CurrentTarget = nil
    local StateChangedCallback = nil

    local VisibilityParams =
        RaycastParams.new()

    VisibilityParams.FilterType =
        Enum.RaycastFilterType.Exclude

    VisibilityParams.IgnoreWater =
        true

    local ParentGui =
        LocalPlayer:WaitForChild("PlayerGui")

    local OldGui =
        ParentGui:
            FindFirstChild(
                "NEWZ_AimAssist"
            )

    if OldGui then
        OldGui:Destroy()
    end

    local ScreenGui =
        Instance.new(
            "ScreenGui"
        )

    ScreenGui.Name =
        "NEWZ_AimAssist"

    ScreenGui.IgnoreGuiInset =
        true

    ScreenGui.ResetOnSpawn =
        false

    ScreenGui.DisplayOrder =
        996

    ScreenGui.Parent =
        ParentGui

    local FOVCircle =
        Instance.new(
            "Frame"
        )

    FOVCircle.Name =
        "FOV"

    FOVCircle.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    FOVCircle.BackgroundTransparency =
        1

    FOVCircle.Visible =
        false

    FOVCircle.Parent =
        ScreenGui

    local Aspect =
        Instance.new(
            "UIAspectRatioConstraint"
        )

    Aspect.AspectRatio =
        1

    Aspect.Parent =
        FOVCircle

    local Corner =
        Instance.new(
            "UICorner"
        )

    Corner.CornerRadius =
        UDim.new(
            1,
            0
        )

    Corner.Parent =
        FOVCircle

    local Stroke =
        Instance.new(
            "UIStroke"
        )

    Stroke.Thickness =
        1

    Stroke.Transparency =
        0.15

    Stroke.Parent =
        FOVCircle

    local Controller = {}

    local function Notify()
        if
            type(StateChangedCallback)
            == "function"
        then
            pcall(
                StateChangedCallback,
                Active,
                CurrentTarget
            )
        end
    end

    local function IsTeammate(
        Player
    )
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
            LocalPlayer.Team
            == Player.Team
    end

    local function IsVisible(
        Character,
        TargetPart,
        Camera
    )
        if
            Settings.VisibilityCheck
            ~= true
        then
            return true
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

        local Result =
            Workspace:Raycast(
                Origin,
                TargetPart.Position
                    - Origin,
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

    local function ResolveTargetPart(
        Character
    )
        local TargetName =
            tostring(
                Settings.TargetPart
                or "Head"
            )

        local Target =
            Character:
                FindFirstChild(
                    TargetName
                )

        if
            Target
            and Target:IsA(
                "BasePart"
            )
        then
            return Target
        end

        for _, Name
            in ipairs({
                "Head",
                "HumanoidRootPart",
                "UpperTorso",
                "Torso",
            })
        do
            Target =
                Character:
                    FindFirstChild(
                        Name
                    )

            if
                Target
                and Target:IsA(
                    "BasePart"
                )
            then
                return Target
            end
        end

        return nil
    end

    local function FindBestTarget(
        Camera
    )
        local Mouse =
            UserInputService:
                GetMouseLocation()

        local FOV =
            math.max(
                10,
                tonumber(
                    Settings.FOV
                )
                or 150
            )

        local MaxDistance =
            math.max(
                1,
                tonumber(
                    Settings.MaxDistance
                )
                or 1000
            )

        local BestPlayer = nil
        local BestPart = nil
        local BestScreenDistance =
            math.huge

        for _, Player
            in ipairs(
                Players:
                    GetPlayers()
            )
        do
            if
                Player
                ~= LocalPlayer
                and not IsTeammate(
                    Player
                )
            then
                local Character =
                    Player.Character

                local Humanoid =
                    Character
                    and Character:
                        FindFirstChildOfClass(
                            "Humanoid"
                        )

                local Root =
                    Character
                    and Character:
                        FindFirstChild(
                            "HumanoidRootPart"
                        )

                if
                    Character
                    and Humanoid
                    and Root
                    and Humanoid.Health
                        > 0
                    and (
                        Root.Position
                        - Camera.CFrame.Position
                    ).Magnitude
                        <= MaxDistance
                then
                    local TargetPart =
                        ResolveTargetPart(
                            Character
                        )

                    if TargetPart then
                        local Point,
                            OnScreen =
                                Camera:
                                    WorldToViewportPoint(
                                        TargetPart.Position
                                    )

                        if
                            OnScreen
                            and Point.Z > 0
                        then
                            local ScreenDistance =
                                (
                                    Vector2.new(
                                        Point.X,
                                        Point.Y
                                    )
                                    - Mouse
                                ).Magnitude

                            if
                                ScreenDistance
                                <= FOV
                                and ScreenDistance
                                    < BestScreenDistance
                                and IsVisible(
                                    Character,
                                    TargetPart,
                                    Camera
                                )
                            then
                                BestScreenDistance =
                                    ScreenDistance

                                BestPlayer =
                                    Player

                                BestPart =
                                    TargetPart
                            end
                        end
                    end
                end
            end
        end

        return
            BestPlayer,
            BestPart
    end

    local function UpdateFOV()
        local Enabled =
            Settings.Enabled
            == true
            and Settings.ShowFOV
                ~= false

        FOVCircle.Visible =
            Enabled

        if not Enabled then
            return
        end

        local Radius =
            math.max(
                10,
                tonumber(
                    Settings.FOV
                )
                or 150
            )

        local Mouse =
            UserInputService:
                GetMouseLocation()

        FOVCircle.Position =
            UDim2.fromOffset(
                Mouse.X,
                Mouse.Y
            )

        FOVCircle.Size =
            UDim2.fromOffset(
                Radius * 2,
                Radius * 2
            )

        Stroke.Color =
            Settings.FOVColor
            or Color3.new(
                1,
                1,
                1
            )
    end

    local function Step(
        DeltaTime
    )
        if Destroyed then
            return
        end

        UpdateFOV()

        if
            Settings.Enabled
            ~= true
            or not Active
            or (
                Config.Freecam
                and Config.Freecam.Enabled
                    == true
            )
        then
            if CurrentTarget then
                CurrentTarget =
                    nil

                Notify()
            end

            return
        end

        local Camera =
            Workspace.CurrentCamera

        if not Camera then
            return
        end

        local Player,
            TargetPart =
                FindBestTarget(
                    Camera
                )

        if
            CurrentTarget
            ~= Player
        then
            CurrentTarget =
                Player

            Notify()
        end

        if not TargetPart then
            return
        end

        local TargetCFrame =
            CFrame.lookAt(
                Camera.CFrame.Position,
                TargetPart.Position
            )

        local Responsiveness =
            math.max(
                0.01,
                tonumber(
                    Settings.Responsiveness
                )
                or 18
            )

        local Alpha =
            1
            - math.exp(
                -Responsiveness
                * math.min(
                    DeltaTime,
                    0.1
                )
            )

        Camera.CFrame =
            Camera.CFrame:
                Lerp(
                    TargetCFrame,
                    Alpha
                )
    end

    local RenderStepName =
        "NEWZ_AimAssist_"
        .. tostring(
            LocalPlayer.UserId
        )

    RunService:
        BindToRenderStep(
            RenderStepName,
            Enum.RenderPriority.Camera.Value
                + 1,
            Step
        )

    function Controller.SetHeld(
        Value
    )
        Active =
            Value == true

        if not Active then
            CurrentTarget =
                nil
        end

        Notify()
    end

    function Controller.ToggleActive()
        Active =
            not Active

        if not Active then
            CurrentTarget =
                nil
        end

        Notify()

        return Active
    end

    function Controller.SetEnabled(
        Value
    )
        Settings.Enabled =
            Value == true

        if not Settings.Enabled then
            Active =
                false

            CurrentTarget =
                nil
        end

        Notify()
    end

    function Controller.IsActive()
        return Active
    end

    function Controller.GetTarget()
        return CurrentTarget
    end

    function Controller.SetStateChangedCallback(
        Callback
    )
        if
            Callback ~= nil
            and type(Callback)
                ~= "function"
        then
            return false
        end

        StateChangedCallback =
            Callback

        if Callback then
            Notify()
        end

        return true
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed =
            true

        pcall(
            RunService.UnbindFromRenderStep,
            RunService,
            RenderStepName
        )

        if ScreenGui then
            pcall(
                ScreenGui.Destroy,
                ScreenGui
            )
        end

        StateChangedCallback =
            nil
    end

    return Controller
end

return AimAssist
