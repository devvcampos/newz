local Freecam = {}

function Freecam.Init(Config)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer

    assert(LocalPlayer, "Freecam precisa ser inicializada no cliente")

    Config.Freecam = Config.Freecam or {}

    local Settings = Config.Freecam

    local Destroyed = false
    local Enabled = false

    local SavedCameraState = nil
    local RenderConnection = nil
    local StateChangedCallback = nil

    local CameraPosition = Vector3.zero
    local CameraPitch = 0
    local CameraYaw = 0

    local KeyState = {}

    local MovementActionName = "NEWZ_FreecamMovement_" .. tostring(LocalPlayer.UserId)

    local Controller = {}

    local function ResolveKeyCode(Value)
        if typeof(Value) == "EnumItem" and Value.EnumType == Enum.KeyCode then
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

    local function GetCharacter()
        local Character = LocalPlayer.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if not Character or not Root or not Root:IsA("BasePart") then
            return nil, nil
        end

        return Character, Root
    end

    local function StopCharacterMotion(Character)
        if not Character then return end

        for _, Object in ipairs(Character:GetDescendants()) do
            if Object:IsA("BasePart") then
                Object.AssemblyLinearVelocity = Vector3.zero
                Object.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    local function GetExitCFrame(CameraCFrame)
        local Position = CameraCFrame.Position

        if Settings.SnapToGround ~= false then
            local Character = LocalPlayer.Character
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude

            if Character then
                Params.FilterDescendantsInstances = {Character}
            else
                Params.FilterDescendantsInstances = {}
            end

            local ProbeDistance = math.clamp(tonumber(Settings.GroundProbeDistance) or 200, 10, 1000)
            local Result = Workspace:Raycast(
                Position + Vector3.new(0, 4, 0),
                Vector3.new(0, -ProbeDistance, 0),
                Params
            )

            if Result then
                local Offset = math.clamp(tonumber(Settings.GroundOffset) or 3, 1, 8)
                Position = Result.Position + Vector3.new(0, Offset, 0)
            end
        end

        local Look = CameraCFrame.LookVector
        local FlatLook = Vector3.new(Look.X, 0, Look.Z)

        if FlatLook.Magnitude < 0.001 then
            local _, Root = GetCharacter()
            if Root then
                local RootLook = Root.CFrame.LookVector
                FlatLook = Vector3.new(RootLook.X, 0, RootLook.Z)
            end
        end

        if FlatLook.Magnitude < 0.001 then
            FlatLook = Vector3.new(0, 0, -1)
        else
            FlatLook = FlatLook.Unit
        end

        return CFrame.lookAt(Position, Position + FlatLook)
    end

 local function MoveCharacterToCamera(CameraCFrame)
    local Character, Root = GetCharacter()
    if not Character then
        return false, "Personagem nao esta pronto"
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then
        return false, "Humanoid nao encontrado"
    end

    local Destination = GetExitCFrame(CameraCFrame)
    local DestPos = Destination.Position

    -- ===== MODO "GLIDE" (suave, sem rollback) =====
    local Mode = Settings.TeleportMode or "Glide"

    if Mode == "Glide" then
        -- Desanchar o personagem para permitir movimento
        Root.Anchored = false

        -- Configurar a velocidade média (máximo 100 para não ser detectado)
        local Speed = math.clamp(Settings.VelocitySpeed or 80, 10, 100)
        
        -- Calcular direção (inclui vertical)
        local Direction = (DestPos - Root.Position).Unit
        local Distance = (DestPos - Root.Position).Magnitude

        if Distance < 1 then
            return true, "Ja esta no destino"
        end

        -- Criar um BodyVelocity para empurrar suavemente
        local BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6) -- força máxima
        BodyVelocity.Velocity = Direction * Speed
        BodyVelocity.Parent = Root

        -- Aguardar até chegar perto do destino (ou timeout)
        local Start = os.clock()
        local Timeout = math.clamp(Distance / Speed + 1, 1, 30) -- tempo máximo

        while os.clock() - Start < Timeout do
            task.wait(0.1)

            -- Se chegou perto o suficiente, parar
            if (Root.Position - DestPos).Magnitude < 3 then
                BodyVelocity:Destroy()
                return true, "Movimento concluido (Glide)"
            end
        end

        -- Se timeout, parar e deixar onde está (sem forçar)
        BodyVelocity:Destroy()
        return false, "Timeout - personagem parou no caminho"
    end

    -- ===== MODO WALK (fallback seguro) =====
    if Mode == "Walk" then
        Root.Anchored = false
        Humanoid.WalkSpeed = math.clamp(Settings.WalkSpeed or 250, 16, 256)

        Humanoid:MoveTo(DestPos)

        local Start = os.clock()
        local Timeout = Settings.WalkTimeout or 6

        while os.clock() - Start < Timeout do
            task.wait(0.1)
            if (Root.Position - DestPos).Magnitude < 3 then
                Humanoid.WalkSpeed = 16
                return true, "Movimento concluido (Walk)"
            end
        end

        Humanoid.WalkSpeed = 16
        return false, "Walk timeout"
    end

    -- ===== MODO NONE =====
    return false, "Teleporte desativado"
end

    -- ================================================

    local function MovementAction(_, InputState, InputObject)
        if not Enabled then
            return Enum.ContextActionResult.Pass
        end

        local KeyCode = InputObject.KeyCode

        if InputState == Enum.UserInputState.Begin or InputState == Enum.UserInputState.Change then
            KeyState[KeyCode] = true
        elseif InputState == Enum.UserInputState.End or InputState == Enum.UserInputState.Cancel then
            KeyState[KeyCode] = nil
        end

        return Enum.ContextActionResult.Sink
    end

    local function BindMovement()
        table.clear(KeyState)

        ContextActionService:BindActionAtPriority(
            MovementActionName,
            MovementAction,
            false,
            Enum.ContextActionPriority.High.Value + 100,
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.Space,
            Enum.KeyCode.LeftControl,
            Enum.KeyCode.RightControl,
            Enum.KeyCode.LeftShift,
            Enum.KeyCode.RightShift
        )
    end

    local function UnbindMovement()
        ContextActionService:UnbindAction(MovementActionName)
        table.clear(KeyState)
    end

    local function IsDown(KeyCode)
        return KeyState[KeyCode] == true
    end

    local function UpdateCamera(DeltaTime)
        if not Enabled or Destroyed then
            return
        end

        local Camera = Workspace.CurrentCamera
        if not Camera then
            return
        end

        local MouseDelta = UserInputService:GetMouseDelta()
        local Sensitivity = math.clamp(tonumber(Settings.MouseSensitivity) or 0.12, 0.01, 1)
        local RadiansPerPixel = math.rad(Sensitivity)

        CameraYaw = CameraYaw - MouseDelta.X * RadiansPerPixel
        CameraPitch = math.clamp(CameraPitch - MouseDelta.Y * RadiansPerPixel, math.rad(-89), math.rad(89))

        local Rotation = CFrame.fromOrientation(CameraPitch, CameraYaw, 0)

        local X = (IsDown(Enum.KeyCode.D) and 1 or 0) - (IsDown(Enum.KeyCode.A) and 1 or 0)
        local Y = (IsDown(Enum.KeyCode.Space) and 1 or 0) - ((IsDown(Enum.KeyCode.LeftControl) or IsDown(Enum.KeyCode.RightControl)) and 1 or 0)
        local Z = (IsDown(Enum.KeyCode.W) and 1 or 0) - (IsDown(Enum.KeyCode.S) and 1 or 0)

        local Move = Rotation.RightVector * X + Vector3.new(0, 1, 0) * Y + Rotation.LookVector * Z
        if Move.Magnitude > 1 then
            Move = Move.Unit
        end

        local Speed = math.clamp(tonumber(Settings.Speed) or 55, 1, 500)

        if IsDown(Enum.KeyCode.LeftShift) or IsDown(Enum.KeyCode.RightShift) then
            Speed = Speed * math.clamp(tonumber(Settings.BoostMultiplier) or 3, 1, 10)
        end

        CameraPosition = CameraPosition + Move * Speed * math.min(DeltaTime, 0.1)

        local CameraCFrame = CFrame.new(CameraPosition) * Rotation

        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = CameraCFrame
        Camera.Focus = CFrame.new(CameraPosition + Rotation.LookVector * 512)
    end

    local function DisableInternal(TeleportCharacter)
        if not Enabled then
            return true, "Freecam ja esta desativada"
        end

        local Camera = Workspace.CurrentCamera
        local FinalCameraCFrame = Camera and Camera.CFrame or (SavedCameraState and SavedCameraState.CFrame)

        Enabled = false

        if RenderConnection then
            RenderConnection:Disconnect()
            RenderConnection = nil
        end

        UnbindMovement()

        local TeleportSuccess = true
        local TeleportMessage = "Freecam desativada"

        if TeleportCharacter and Settings.TeleportOnExit ~= false and FinalCameraCFrame then
            TeleportSuccess, TeleportMessage = MoveCharacterToCamera(FinalCameraCFrame)
        end

        if Camera and SavedCameraState then
            Camera.FieldOfView = SavedCameraState.FieldOfView
            Camera.CameraSubject = SavedCameraState.CameraSubject
            Camera.CameraType = SavedCameraState.CameraType

            if TeleportCharacter and Settings.TeleportOnExit ~= false and FinalCameraCFrame then
                Camera.CFrame = FinalCameraCFrame
            else
                Camera.CFrame = SavedCameraState.CFrame
                Camera.Focus = SavedCameraState.Focus
            end
        end

        if SavedCameraState then
            UserInputService.MouseBehavior = SavedCameraState.MouseBehavior
            UserInputService.MouseIconEnabled = SavedCameraState.MouseIconEnabled
        end

        SavedCameraState = nil
        NotifyStateChanged()

        if not TeleportSuccess then
            return false, TeleportMessage
        end

        return true, TeleportMessage
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

        BindMovement()
        RenderConnection = RunService.RenderStepped:Connect(UpdateCamera)

        NotifyStateChanged()

        return true, "Freecam ativada"
    end

    function Controller.Disable()
        if Destroyed then
            return false, "Freecam foi destruida"
        end

        return DisableInternal(true)
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
        Settings.Speed = math.clamp(tonumber(Value) or Settings.Speed or 55, 1, 500)
        return Settings.Speed
    end

    function Controller.SetBoostMultiplier(Value)
        Settings.BoostMultiplier = math.clamp(tonumber(Value) or Settings.BoostMultiplier or 3, 1, 10)
        return Settings.BoostMultiplier
    end

    function Controller.SetMouseSensitivity(Value)
        Settings.MouseSensitivity = math.clamp(tonumber(Value) or Settings.MouseSensitivity or 0.12, 0.01, 1)
        return Settings.MouseSensitivity
    end

    function Controller.SetTeleportOnExit(Value)
        Settings.TeleportOnExit = Value == true
    end

    function Controller.SetSnapToGround(Value)
        Settings.SnapToGround = Value == true
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

    local ToggleConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if Destroyed or GameProcessed then
            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if Input.KeyCode == ToggleKey then
            Controller.Toggle()
        end
    end)

    function Controller.Destroy()
        if Destroyed then
            return
        end

        DisableInternal(false)
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