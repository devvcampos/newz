local PlayerTools = {}

function PlayerTools.Init(Config)
    local Players =
        game:GetService("Players")

    local Workspace =
        game:GetService("Workspace")

    local LocalPlayer =
        Players.LocalPlayer

    assert(
        LocalPlayer,
        "PlayerTools precisa ser inicializado no cliente"
    )

    Config.PlayerTools =
        Config.PlayerTools
        or {}

    local Settings =
        Config.PlayerTools

    local Destroyed = false
    local SpectatingPlayer = nil
    local SavedCameraSubject = nil
    local StateChangedCallback = nil

    local Connections = {}

    local VisibilityParams =
        RaycastParams.new()

    VisibilityParams.FilterType =
        Enum.RaycastFilterType.Exclude

    VisibilityParams.IgnoreWater =
        true

    local Controller = {}

    local function Notify(
        EventName,
        Value
    )
        if
            type(StateChangedCallback)
            == "function"
        then
            pcall(
                StateChangedCallback,
                EventName,
                Value
            )
        end
    end

    local function FindPlayerByName(
        Name
    )
        local Query =
            string.lower(
                tostring(
                    Name
                    or ""
                )
            )

        if Query == "" then
            return nil
        end

        for _, Player
            in ipairs(
                Players:
                    GetPlayers()
            )
        do
            if
                Player ~= LocalPlayer
                and (
                    string.lower(
                        Player.Name
                    )
                    == Query
                    or string.lower(
                        Player.DisplayName
                    )
                    == Query
                )
            then
                return Player
            end
        end

        return nil
    end

    local function GetLocalRoot()
        local Character =
            LocalPlayer.Character

        return
            Character
            and Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
    end

    local function IsVisible(
        Character,
        TargetPart
    )
        local Camera =
            Workspace.CurrentCamera

        if
            not Camera
            or not Character
            or not TargetPart
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

    function Controller.GetPlayerNames()
        local Result = {}

        for _, Player
            in ipairs(
                Players:
                    GetPlayers()
            )
        do
            if Player ~= LocalPlayer then
                Result[
                    #Result + 1
                ] =
                    Player.Name
            end
        end

        table.sort(
            Result,
            function(
                A,
                B
            )
                return
                    string.lower(A)
                    < string.lower(B)
            end
        )

        return Result
    end

    function Controller.Select(
        Name
    )
        local Player =
            FindPlayerByName(
                Name
            )

        if not Player then
            Settings.SelectedName =
                ""

            Notify(
                "Selection",
                nil
            )

            return false,
                "Player nao encontrado"
        end

        Settings.SelectedName =
            Player.Name

        Notify(
            "Selection",
            Player
        )

        return true,
            Player
    end

    function Controller.GetSelectedPlayer()
        return
            FindPlayerByName(
                Settings.SelectedName
            )
    end

    function Controller.GetInfo(
        Player
    )
        Player =
            Player
            or Controller:
                GetSelectedPlayer()

        if not Player then
            return nil
        end

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

        local Head =
            Character
            and Character:
                FindFirstChild(
                    "Head"
                )

        local Health =
            Humanoid
            and Humanoid.Health
            or 0

        local MaxHealth =
            Humanoid
            and Humanoid.MaxHealth
            or 0

        local LocalRoot =
            GetLocalRoot()

        local Distance =
            (
                Root
                and LocalRoot
            )
            and (
                Root.Position
                - LocalRoot.Position
            ).Magnitude
            or nil

        local Friend =
            false

        pcall(function()
            Friend =
                LocalPlayer:
                    IsFriendsWith(
                        Player.UserId
                    )
        end)

        local Visible =
            Character
            and IsVisible(
                Character,
                Head
                or Root
            )
            or false

        local TeamName =
            Player.Team
            and Player.Team.Name
            or "-"

        return {
            Player =
                Player,

            Name =
                Player.Name,

            DisplayName =
                Player.DisplayName,

            UserId =
                Player.UserId,

            Health =
                Health,

            MaxHealth =
                MaxHealth,

            Alive =
                Humanoid ~= nil
                and Health > 0,

            Distance =
                Distance,

            Friend =
                Friend,

            Visible =
                Visible,

            Team =
                TeamName,
        }
    end

    function Controller.Spectate(
        Player
    )
        if Destroyed then
            return false,
                "PlayerTools foi destruido"
        end

        Player =
            Player
            or Controller:
                GetSelectedPlayer()

        if not Player then
            return false,
                "Selecione um player"
        end

        local Character =
            Player.Character

        local Humanoid =
            Character
            and Character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        local Camera =
            Workspace.CurrentCamera

        if
            not Camera
            or not Humanoid
        then
            return false,
                "Player sem Humanoid/camera"
        end

        if not SpectatingPlayer then
            SavedCameraSubject =
                Camera.CameraSubject
        end

        SpectatingPlayer =
            Player

        Camera.CameraSubject =
            Humanoid

        Notify(
            "Spectate",
            Player
        )

        return true,
            Player.Name
    end

    function Controller.StopSpectate()
        local Camera =
            Workspace.CurrentCamera

        if Camera then
            local LocalCharacter =
                LocalPlayer.Character

            local LocalHumanoid =
                LocalCharacter
                and LocalCharacter:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            Camera.CameraSubject =
                LocalHumanoid
                or SavedCameraSubject
                or Camera.CameraSubject
        end

        SpectatingPlayer =
            nil

        SavedCameraSubject =
            nil

        Notify(
            "Spectate",
            nil
        )

        return true
    end

    function Controller.IsSpectating()
        return
            SpectatingPlayer
            ~= nil
    end

    function Controller.GetSpectatingPlayer()
        return
            SpectatingPlayer
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

        return true
    end

    Connections.PlayerRemoving =
        Players.PlayerRemoving:
            Connect(function(
                Player
            )
                if
                    SpectatingPlayer
                    == Player
                then
                    Controller:
                        StopSpectate()
                end

                if
                    Settings.SelectedName
                    == Player.Name
                then
                    Settings.SelectedName =
                        ""

                    Notify(
                        "Selection",
                        nil
                    )
                end
            end)

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed =
            true

        Controller:
            StopSpectate()

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

        StateChangedCallback =
            nil
    end

    return Controller
end

return PlayerTools
