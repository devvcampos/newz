local SensoryESP = {}

function SensoryESP.Init(Config)
    Config.ExternalESP = Config.ExternalESP or {}

    local Settings = Config.ExternalESP
    local Loaded = false
    local Library = nil
    local LastError = nil
    local StateChangedCallback = nil

    local Controller = {}

    local function Notify()
        if type(StateChangedCallback) == "function" then
            pcall(
                StateChangedCallback,
                Loaded,
                LastError
            )
        end
    end

    local function BuildConfig()
        local ESP = Config.ESP or {}

        return {
            Boxes = ESP.Box == true,
            BoxType = ESP.BoxStyle or "Normal",
            BoxColor = ESP.VisibleColor,
            BoxThickness = ESP.BoxThickness or 1,
            Outlines = ESP.Outlines == true,

            Names = ESP.Name == true,

            Distance = {
                Enabled = ESP.Distance == true,
                Unit = "Meters",
                Ending = "m",
            },

            HealthBar = ESP.HealthBar,
            Chams = ESP.Chams,
            Skeleton = ESP.Skeleton,
            Flags = ESP.Flags,
            OffScreenArrows = ESP.OffScreenArrows,
            VisibleCheck = ESP.VisibilityCheck == true,
        }
    end

    function Controller.Load()
        if Loaded then
            return true, "sensoryESP ja esta carregado"
        end

        if Settings.Enabled ~= true then
            return false, "sensoryESP remoto esta desativado na Config"
        end

        if type(loadstring) ~= "function" then
            LastError = "loadstring indisponivel"
            Notify()
            return false, LastError
        end

        local URL = tostring(
            Settings.URL
            or "https://raw.githubusercontent.com/rthusrtghdfhtyjkehrfh/sensoryESP/main/ESP.lua"
        )

        local Success,
            Result =
                pcall(function()
                    local Source = game:HttpGet(URL)
                    local Chunk, LoadError = loadstring(
                        Source,
                        "@newz/external/sensoryESP"
                    )

                    assert(
                        Chunk,
                        tostring(LoadError)
                    )

                    return Chunk()
                end)

        if not Success then
            LastError = tostring(Result)
            Notify()
            return false, LastError
        end

        Library = Result
        Loaded = true
        LastError = nil

        if
            type(Library) == "table"
            and type(Library.Load) == "function"
        then
            pcall(
                Library.Load,
                Library,
                BuildConfig()
            )
        end

        Notify()
        return true, "sensoryESP remoto carregado"
    end

    function Controller.Refresh()
        if not Loaded or type(Library) ~= "table" then
            return false, "sensoryESP nao esta carregado"
        end

        local Updated = false
        local NewConfig = BuildConfig()

        for _, Name in ipairs({
            "UpdateConfig",
            "SetConfig",
            "UpdateSettings",
            "Update",
            "Refresh",
            "Load",
        }) do
            local Method = Library[Name]

            if type(Method) == "function" then
                local Success = pcall(
                    Method,
                    Library,
                    NewConfig
                )

                if Success then
                    Updated = true
                    break
                end
            end
        end

        return Updated,
            Updated
            and "sensoryESP atualizado"
            or "nenhum metodo de update compativel"
    end

    function Controller.Unload()
        if not Loaded then
            return true, "sensoryESP ja esta descarregado"
        end

        if
            type(Library) == "table"
            and type(Library.Unload) == "function"
        then
            pcall(
                Library.Unload,
                Library
            )
        end

        Library = nil
        Loaded = false
        LastError = nil
        Notify()

        return true, "sensoryESP descarregado"
    end

    function Controller.SetEnabled(Value)
        Settings.Enabled = Value == true

        if Settings.Enabled then
            return Controller.Load()
        end

        return Controller.Unload()
    end

    function Controller.IsLoaded()
        return Loaded
    end

    function Controller.GetLibrary()
        return Library
    end

    function Controller.SetStateChangedCallback(Callback)
        if Callback ~= nil and type(Callback) ~= "function" then
            return false
        end

        StateChangedCallback = Callback
        Notify()
        return true
    end

    function Controller.Destroy()
        Controller.Unload()
        StateChangedCallback = nil
    end

    if Settings.Enabled == true and Settings.AutoLoad == true then
        task.defer(Controller.Load)
    end

    return Controller
end

return SensoryESP
