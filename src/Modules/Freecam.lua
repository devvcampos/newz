local Freecam = {}

function Freecam.Init(Config)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer

    assert(
        LocalPlayer,
        "Freecam precisa ser inicializada no cliente"
    )

    Config.Freecam = Config.Freecam or {}
    local Settings = Config.Freecam

    local Destroyed = false
    local Enabled = false

    local SavedCameraState = nil
    local RenderConnection = nil
    local InputBeganConnection = nil
    local InputEndedConnection = nil
    local ToggleConnection = nil
    local StateChangedCallback = nil

    local CameraPosition = Vector3.zero
    local CameraPitch = 0
    local CameraYaw = 0
    local KeyState = {}

    local Controller = {}

    local function ResolveKeyCode(Value)
        if
            typeof(Value) == "EnumItem"
            and Value.EnumType == Enum.KeyCode
        then
            return Value
        end

        local Name = tostring(Value or "V")
        Name = string.gsub(Name, "^Enum%.KeyCode%.", "")

        return Enum.KeyCode[Name] or Enum.KeyCode.V
    end

    local ToggleKey = ResolveKeyCode(Settings.Keybind)

    local function NotifyStateChanged()
        Settings.Enabled = Enabled

        if type(StateChangedCallback) == "function" then
            pcall(StateChangedCallback, Enabled)
        end
    end

    local function IsDown(KeyCode)
        return KeyState[KeyCode] == true
    end

    local function ClearInput()
        table.clear(KeyState)
    end

    local function DisconnectFreecamInput()
        if InputBeganConnection then
            InputBeganConnection:Disconnect()
            InputBeganConnection = nil
        end

        if InputEndedConnection then
            InputEndedConnection:Disconnect()
            InputEndedConnection = nil
        end

        ClearInput()
    end

    local function BindFreecamInput()
        DisconnectFreecamInput()

        InputBeganConnection =
            UserInputService.InputBegan:Connect(function(Input, GameProcessed)
                if Destroyed or not Enabled or GameProcessed then
                    return
                end

                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    KeyState[Input.KeyCode] = true
                end
            end)

        InputEndedConnection =
            UserInputService.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    KeyState[Input.KeyCode] = nil
                end
            end)
    end

    local function UpdateCamera(DeltaTime)
        if Destroyed or not Enabled then
            return
        end

        local Camera = Workspace.CurrentCamera
        if not Camera then
            return
        end

        local MouseDelta = UserInputService:GetMouseDelta()
        local Sensitivity =
            math.clamp(
                tonumber(Settings.MouseSensitivity) or 0.12,
                0.01,
                1
            )

        CameraYaw -= math.rad(MouseDelta.X * Sensitivity)
        CameraPitch -= math.rad(MouseDelta.Y * Sensitivity)
        CameraPitch = math.clamp(
            CameraPitch,
            math.rad(-89),
            math.rad(89)
        )

        local Rotation =
            CFrame.fromOrientation(
                CameraPitch,
                CameraYaw,
                0
            )

        local Direction = Vector3.zero

        if IsDown(Enum.KeyCode.W) then
            Direction += Vector3.new(0, 0, -1)
        end

        if IsDown(Enum.KeyCode.S) then
            Direction += Vector3.new(0, 0, 1)
        end

        if IsDown(Enum.KeyCode.A) then
            Direction += Vector3.new(-1, 0, 0)
        end

        if IsDown(Enum.KeyCode.D) then
            Direction += Vector3.new(1, 0, 0)
        end

        if IsDown(Enum.KeyCode.Space) then
            Direction += Vector3.new(0, 1, 0)
        end

        if
            IsDown(Enum.KeyCode.LeftControl)
            or IsDown(Enum.KeyCode.RightControl)
        then
            Direction += Vector3.new(0, -1, 0)
        end

        local Speed =
            math.clamp(
                tonumber(Settings.Speed) or 55,
                1,
                500
            )

        if
            IsDown(Enum.KeyCode.LeftShift)
            or IsDown(Enum.KeyCode.RightShift)
        then
            Speed *=
                math.clamp(
                    tonumber(Settings.BoostMultiplier) or 3,
                    1,
                    10
                )
        end

        if Direction.Magnitude > 0 then
            Direction = Direction.Unit

            local WorldDirection =
                Rotation:VectorToWorldSpace(Direction)

            CameraPosition +=
                WorldDirection
                * Speed
                * DeltaTime
        end

        Camera.CFrame =
            CFrame.new(CameraPosition)
            * Rotation
    end

    local function DisableInternal()
        if not Enabled then
            return true, "Freecam ja esta desativada"
        end

        Enabled = false

        if RenderConnection then
            RenderConnection:Disconnect()
            RenderConnection = nil
        end

        DisconnectFreecamInput()

        local Camera = Workspace.CurrentCamera

        if Camera and SavedCameraState then
            Camera.CameraType = SavedCameraState.CameraType
            Camera.CameraSubject = SavedCameraState.CameraSubject
            Camera.CFrame = SavedCameraState.CFrame
            Camera.Focus = SavedCameraState.Focus
            Camera.FieldOfView = SavedCameraState.FieldOfView
        end

        if SavedCameraState then
            UserInputService.MouseBehavior = SavedCameraState.MouseBehavior
            UserInputService.MouseIconEnabled = SavedCameraState.MouseIconEnabled
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end

        SavedCameraState = nil
        NotifyStateChanged()

        return true, "Freecam desativada"
    end

    function Controller.Enable()
        if Destroyed then
            return false, "Freecam foi destruida"
        end

        if Enabled then
            return true, "Freecam ja esta ativa"
        end

        local Camera = Workspace.CurrentCamera

        if not Camera then
            return false, "Camera indisponivel"
        end

        SavedCameraState = {
            CameraType = Camera.CameraType,
            CameraSubject = Camera.CameraSubject,
            CFrame = Camera.CFrame,
            Focus = Camera.Focus,
            FieldOfView = Camera.FieldOfView,
            MouseBehavior = UserInputService.MouseBehavior,
            MouseIconEnabled = UserInputService.MouseIconEnabled,
        }

        CameraPosition = Camera.CFrame.Position

        local Pitch, Yaw = Camera.CFrame:ToOrientation()
        CameraPitch = Pitch
        CameraYaw = Yaw

        Enabled = true
        Camera.CameraType = Enum.CameraType.Scriptable
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false

        BindFreecamInput()

        RenderConnection =
            RunService.RenderStepped:Connect(
                UpdateCamera
            )

        NotifyStateChanged()

        return true, "Freecam ativada"
    end

    function Controller.Disable()
        if Destroyed then
            return false, "Freecam foi destruida"
        end

        return DisableInternal()
    end

    function Controller.Toggle()
        if Enabled then
            return Controller.Disable()
        end

        return Controller.Enable()
    end

    function Controller.IsEnabled()
        return Enabled
    end

    function Controller.SetKeybind(Value)
        ToggleKey = ResolveKeyCode(Value)
        Settings.Keybind = ToggleKey.Name
        return ToggleKey.Name
    end

    function Controller.GetKeybind()
        return ToggleKey
    end

    function Controller.SetSpeed(Value)
        Settings.Speed =
            math.clamp(
                tonumber(Value) or Settings.Speed or 55,
                1,
                500
            )

        return Settings.Speed
    end

    function Controller.SetBoostMultiplier(Value)
        Settings.BoostMultiplier =
            math.clamp(
                tonumber(Value) or Settings.BoostMultiplier or 3,
                1,
                10
            )

        return Settings.BoostMultiplier
    end

    function Controller.SetMouseSensitivity(Value)
        Settings.MouseSensitivity =
            math.clamp(
                tonumber(Value) or Settings.MouseSensitivity or 0.12,
                0.01,
                1
            )

        return Settings.MouseSensitivity
    end

    function Controller.SetStateChangedCallback(Callback)
        if Callback ~= nil and type(Callback) ~= "function" then
            return false
        end

        StateChangedCallback = Callback

        if StateChangedCallback then
            pcall(StateChangedCallback, Enabled)
        end

        return true
    end

    ToggleConnection =
        UserInputService.InputBegan:Connect(function(Input, GameProcessed)
            if Destroyed or GameProcessed then
                return
            end

            if UserInputService:GetFocusedTextBox() then
                return
            end

            if
                Input.UserInputType == Enum.UserInputType.Keyboard
                and Input.KeyCode == ToggleKey
            then
                Controller.Toggle()
            end
        end)

    function Controller.Destroy()
        if Destroyed then
            return
        end

        DisableInternal()
        Destroyed = true

        if ToggleConnection then
            ToggleConnection:Disconnect()
            ToggleConnection = nil
        end

        StateChangedCallback = nil
    end

    Settings.Keybind = ToggleKey.Name
    Settings.Enabled = false

    return Controller
end

return Freecam
