local CorpseIllusion = {}

function CorpseIllusion.Init(Config)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    assert(LocalPlayer, "CorpseIllusion precisa ser inicializado no cliente")

    local Settings = Config.CorpseIllusion or {}
    local CorpseSettings = Config.Corpses or {}

    local Destroyed = false
    local CurrentClone = nil
    local CurrentSourceName = nil
    local LocalContainer = nil

    local ReturnCFrame = nil
    local CurrentTeleportTarget = nil
    local BringTask = nil  -- para cancelar loops

    local Controller = {}

    local function GetCorpseFolder()
        local FolderName = tostring(CorpseSettings.FolderName or "Corpses")
        return Workspace:FindFirstChild(FolderName)
    end

    local function EnsureContainer()
        if LocalContainer and LocalContainer.Parent then
            return LocalContainer
        end

        local ContainerName = tostring(Settings.ContainerName or "newz_LocalIllusions")
        local Existing = Workspace:FindFirstChild(ContainerName)
        if Existing then
            Existing:Destroy()
        end

        LocalContainer = Instance.new("Folder")
        LocalContainer.Name = ContainerName
        LocalContainer:SetAttribute("NEWZ_LocalOnly", true)
        LocalContainer.Parent = Workspace

        return LocalContainer
    end

    local function ClearCurrent()
        if CurrentClone then
            pcall(CurrentClone.Destroy, CurrentClone)
            CurrentClone = nil
        end
        CurrentSourceName = nil
        if BringTask then
            task.cancel(BringTask)
            BringTask = nil
        end
    end

    local function FindCorpseByName(TargetName)
        local Folder = GetCorpseFolder()
        if not Folder then
            return nil, "Workspace." .. tostring(CorpseSettings.FolderName or "Corpses") .. " nao encontrada"
        end

        local Query = string.lower(tostring(TargetName or ""))
        if Query == "" then
            return nil, "Selecione um corpo"
        end

        for _, Object in ipairs(Folder:GetChildren()) do
            if Object:IsA("Model") and string.lower(Object.Name) == Query then
                return Object, nil
            end
        end

        return nil, "Corpo nao encontrado"
    end

    local function GetCharacterAndRoot()
        local Character = LocalPlayer.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        if not Character or not Root or not Root:IsA("BasePart") then
            return nil, nil, "Seu personagem nao esta pronto"
        end
        return Character, Root, nil
    end

    local function StopCharacterMotion(Character)
        for _, Object in ipairs(Character:GetDescendants()) do
            if Object:IsA("BasePart") then
                Object.AssemblyLinearVelocity = Vector3.zero
                Object.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    local function StripLocalInteraction(Clone)
        -- Remove coisas que não devem estar no clone
        local LootContainer = Clone:FindFirstChild("Loot_Corpse", true)
        if LootContainer then
            LootContainer:Destroy()
        end

        for _, Object in ipairs(Clone:GetDescendants()) do
            if Object:IsA("Script") or Object:IsA("LocalScript") or Object:IsA("ModuleScript") or Object:IsA("ClickDetector") or Object:IsA("ProximityPrompt") or Object:IsA("Animator") then
                Object:Destroy()
            elseif Object:IsA("BasePart") then
                Object.Anchored = true
                Object.CanCollide = false
                Object.CanTouch = false
                Object.CanQuery = false
                Object.AssemblyLinearVelocity = Vector3.zero
                Object.AssemblyAngularVelocity = Vector3.zero
            elseif Object:IsA("Sound") then
                Object:Stop()
            elseif Object:IsA("ParticleEmitter") or Object:IsA("Trail") or Object:IsA("Beam") or Object:IsA("Smoke") or Object:IsA("Fire") or Object:IsA("Sparkles") then
                Object.Enabled = false
            end
        end

        local Humanoid = Clone:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid.AutoRotate = false
            Humanoid.PlatformStand = true
            Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end

    local function CloneCorpse(Corpse)
        local PreviousArchivable = Corpse.Archivable
        Corpse.Archivable = true
        local Success, CloneOrError = pcall(Corpse.Clone, Corpse)
        Corpse.Archivable = PreviousArchivable
        if not Success or not CloneOrError then
            return nil, "Nao foi possivel clonar o corpo: " .. tostring(CloneOrError)
        end
        return CloneOrError, nil
    end

    -- ================= NOVA FUNÇÃO: BringCorpseToMe =================
    function Controller.BringCorpseToMe(TargetName)
        if Destroyed then return false, "CorpseIllusion foi destruido" end

        local Character, Root, CharacterError = GetCharacterAndRoot()
        if not Character then return false, CharacterError end

        local Corpse, FindError = FindCorpseByName(TargetName)
        if not Corpse then return false, FindError or "Corpo nao encontrado" end

        -- Cancelar qualquer bring anterior
        if BringTask then task.cancel(BringTask) end

        -- Calcular posição alvo: na frente do jogador
        local Distance = math.clamp(tonumber(Settings.Distance) or 5, 2, 20)
        local FlatLook = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)
        if FlatLook.Magnitude < 0.001 then
            FlatLook = Vector3.new(0, 0, -1)
        else
            FlatLook = FlatLook.Unit
        end

        local TargetPosition = Root.Position + FlatLook * Distance
        -- Ajustar altura (para ficar no chão, se possível)
        local RayOrigin = TargetPosition + Vector3.new(0, 10, 0)
        local RayDirection = Vector3.new(0, -20, 0)
        local Params = RaycastParams.new()
        Params.FilterDescendantsInstances = {Character, Corpse}
        Params.FilterType = Enum.RaycastFilterType.Exclude
        local RayResult = Workspace:Raycast(RayOrigin, RayDirection, Params)
        if RayResult then
            TargetPosition = RayResult.Position + Vector3.new(0, 0.5, 0)  -- posição do chão + meio corpo
        end

        -- Criar clone visual para feedback (opcional, mas ajuda a ver)
        local Clone, CloneError = CloneCorpse(Corpse)
        if Clone then
            StripLocalInteraction(Clone)
            Clone.Name = "NEWZ_BRING_" .. Corpse.Name
            Clone.Parent = EnsureContainer()
            Clone:PivotTo(CFrame.new(TargetPosition) * (Corpse:GetPivot() - Corpse:GetPivot().Position))
            CurrentClone = Clone
            CurrentSourceName = Corpse.Name
        end

        -- Iniciar movimento do corpo real até o jogador
        BringTask = task.spawn(function()
            local Attempts = 0
            local MaxAttempts = 10
            local WaitTime = 0.05

            -- Salvar posição original para restaurar se falhar?
            local OriginalPivot = Corpse:GetPivot()

            while not Destroyed and Attempts < MaxAttempts do
                -- Tentar mover o corpo real
                pcall(function()
                    Corpse:PivotTo(CFrame.new(TargetPosition) * (Corpse:GetPivot() - Corpse:GetPivot().Position))
                    -- Desanchar para não ser bloqueado
                    local Primary = Corpse.PrimaryPart
                    if Primary then
                        Primary.Anchored = false
                    end
                end)

                task.wait(WaitTime)

                -- Verificar se o corpo realmente se moveu (se ainda está longe, continua)
                local CurrentPos = Corpse:GetPivot().Position
                if (CurrentPos - TargetPosition).Magnitude < 1 then
                    break  -- chegou
                end

                Attempts += 1
            end

            -- Se falhou após muitas tentativas, restaurar posição original?
            if (Corpse:GetPivot().Position - TargetPosition).Magnitude > 1 then
                -- Opcional: tentar uma última vez com mais agressividade
                pcall(function()
                    Corpse:PivotTo(CFrame.new(TargetPosition) * (Corpse:GetPivot() - Corpse:GetPivot().Position))
                end)
                -- Não restaura, pois pode ter conseguido no fim
            end

            BringTask = nil
        end)

        Settings.TargetName = Corpse.Name
        return true, "Trazendo corpo: " .. Corpse.Name
    end
    -- ================================================================

    -- Funções antigas mantidas (GoTo, Show, etc.) - apenas mostro as novas
    function Controller.GetCorpseNames()
        local Result = {}
        local Folder = GetCorpseFolder()
        if not Folder then return Result end
        for _, Object in ipairs(Folder:GetChildren()) do
            if Object:IsA("Model") then
                Result[#Result + 1] = Object.Name
            end
        end
        table.sort(Result, function(A, B) return string.lower(A) < string.lower(B) end)
        return Result
    end

function Controller.Show(TargetName)
    if Destroyed then
        return false, "CorpseIllusion foi destruido"
    end

    local Character, Root, CharacterError =
        GetCharacterAndRoot()

    if not Character then
        return false, CharacterError
    end

    local Corpse, FindError =
        FindCorpseByName(TargetName)

    if not Corpse then
        return false,
            FindError or "Corpo nao encontrado"
    end

    local Clone, CloneError =
        CloneCorpse(Corpse)

    if not Clone then
        return false, CloneError
    end

    ClearCurrent()
    StripLocalInteraction(Clone)

    Clone.Name =
        "NEWZ_LOCAL_" .. Corpse.Name

    Clone:SetAttribute(
        "NEWZ_LocalIllusion",
        true
    )

    Clone:SetAttribute(
        "NEWZ_SourceCorpse",
        Corpse.Name
    )

    Clone.Parent =
        EnsureContainer()

    local Distance =
        math.clamp(
            tonumber(Settings.Distance) or 5,
            2,
            20
        )

    local VerticalOffset =
        math.clamp(
            tonumber(Settings.VerticalOffset) or 0,
            -5,
            5
        )

    local TargetPosition =
        (
            Root.CFrame
            * CFrame.new(
                0,
                VerticalOffset,
                -Distance
            )
        ).Position

    local SourcePivot =
        Corpse:GetPivot()

    local SourceRotation =
        SourcePivot
        - SourcePivot.Position

    Clone:PivotTo(
        CFrame.new(TargetPosition)
        * SourceRotation
    )

    CurrentClone = Clone
    CurrentSourceName = Corpse.Name

    Settings.TargetName =
        Corpse.Name

    return true,
        "Ilusao local: "
        .. Corpse.Name
end


    function Controller.GoTo(TargetName)
        -- (mantido, mas agora melhorado com loop de tentativas)
        if Destroyed then return false, "CorpseIllusion foi destruido" end
        local Character, Root, CharacterError = GetCharacterAndRoot()
        if not Character then return false, CharacterError end
        local Corpse, FindError = FindCorpseByName(TargetName)
        if not Corpse then return false, FindError or "Corpo nao encontrado" end
        if not ReturnCFrame then ReturnCFrame = Character:GetPivot() end
        local CorpsePivot = Corpse:GetPivot()
        local TeleportDistance = math.clamp(tonumber(Settings.TeleportDistance) or 4, 2, 12)
        local TeleportHeight = math.clamp(tonumber(Settings.TeleportHeight) or 3, 0, 8)
        local FlatLook = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)
        if FlatLook.Magnitude < 0.001 then FlatLook = Vector3.new(0, 0, -1) else FlatLook = FlatLook.Unit end
        local CorpsePosition = CorpsePivot.Position
        local TargetPosition = CorpsePosition - FlatLook * TeleportDistance + Vector3.new(0, TeleportHeight, 0)
        StopCharacterMotion(Character)
        -- Tentativas múltiplas
        for Attempt = 1, 3 do
            Character:PivotTo(CFrame.lookAt(TargetPosition, CorpsePosition))
            StopCharacterMotion(Character)
            task.wait(0.1)
            if (Character:GetPivot().Position - TargetPosition).Magnitude < 2 then break end
        end
        CurrentTeleportTarget = Corpse.Name
        Settings.TargetName = Corpse.Name
        return true, "Movido para perto de " .. Corpse.Name
    end

    function Controller.ReturnToPreviousPosition()
        if Destroyed then return false, "CorpseIllusion foi destruido" end
        if not ReturnCFrame then return false, "Nenhuma posicao anterior salva" end
        local Character, _, CharacterError = GetCharacterAndRoot()
        if not Character then return false, CharacterError end
        local Destination = ReturnCFrame
        ReturnCFrame = nil
        CurrentTeleportTarget = nil
        StopCharacterMotion(Character)
        Character:PivotTo(Destination)
        StopCharacterMotion(Character)
        return true, "Posicao restaurada"
    end

    function Controller.Clear()
        if Destroyed then return false, "CorpseIllusion foi destruido" end
        local HadClone = CurrentClone ~= nil
        ClearCurrent()
        if HadClone then return true, "Ilusao removida" end
        return true, "Nenhuma ilusao ativa"
    end

    function Controller.GetCurrentName()
        return CurrentSourceName
    end

    function Controller.GetTeleportTarget()
    return CurrentTeleportTarget
end

function Controller.HasReturnPosition()
    return ReturnCFrame ~= nil
end

    function Controller.Destroy()
        if Destroyed then return end
        Destroyed = true
        ClearCurrent()
        ReturnCFrame = nil
        CurrentTeleportTarget = nil
        if LocalContainer then pcall(LocalContainer.Destroy, LocalContainer) LocalContainer = nil end
    end

    return Controller
end

return CorpseIllusion