local RemoteBridge = {}

function RemoteBridge.Init(Config)
    Config.RemoteBridge = Config.RemoteBridge or {}
    local Settings = Config.RemoteBridge

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")

    local Controller = {}

    local function GetRoot(Name)
        if Name == "ReplicatedStorage" then
            return ReplicatedStorage
        end

        if Name == "Workspace" then
            return Workspace
        end

        return game:GetService(Name)
    end

    local function ResolveRemote()
        local Path = Settings.Path

        if type(Path) ~= "table" or #Path < 2 then
            return nil, "RemoteBridge.Path invalido"
        end

        local Success, Root = pcall(GetRoot, tostring(Path[1]))

        if not Success or not Root then
            return nil, "servico raiz do remote nao encontrado"
        end

        local Current = Root

        for Index = 2, #Path do
            Current = Current:FindFirstChild(tostring(Path[Index]))

            if not Current then
                return nil,
                    "remote path nao encontrado em "
                    .. tostring(Path[Index])
            end
        end

        if not Current:IsA("RemoteEvent") then
            return nil, "o caminho configurado nao aponta para RemoteEvent"
        end

        return Current
    end

    function Controller.GetPath()
        return Settings.Path
    end

    function Controller.Resolve()
        return ResolveRemote()
    end

    function Controller.Fire(Action, Payload)
        if Settings.Enabled ~= true then
            return false, "RemoteBridge esta desativado"
        end

        local Remote, ErrorMessage = ResolveRemote()

        if not Remote then
            return false, ErrorMessage
        end

        local SafeAction =
            tostring(
                Action
                or Settings.DefaultAction
                or "Ping"
            )

        local Success, FireError = pcall(
            Remote.FireServer,
            Remote,
            SafeAction,
            Payload
        )

        if not Success then
            return false, tostring(FireError)
        end

        return true, "FireServer enviado para o RemoteEvent configurado"
    end

    function Controller.FireTest()
        return Controller.Fire(
            Settings.DefaultAction or "Ping",
            {
                Source = "Newz",
                Version = Config.Project and Config.Project.Version or "unknown",
                Timestamp = os.time(),
            }
        )
    end

    function Controller.SetEnabled(Value)
        Settings.Enabled = Value == true
        return Settings.Enabled
    end

    function Controller.Destroy()
    end

    return Controller
end

return RemoteBridge
