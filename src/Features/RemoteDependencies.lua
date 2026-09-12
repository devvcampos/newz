local RemoteDependencies = {}

function RemoteDependencies.Init(Config)
    local Settings =
        Config.RemoteDependencies
        or {}

    local Loaded = {}
    local Status = {
        Stellar = "not loaded",
        SensoryESP = "not loaded",
    }

    local Destroyed = false

    local function GetHttpGet()
        if
            game
            and type(game.HttpGet)
                == "function"
        then
            return function(Url)
                return game:HttpGet(Url)
            end
        end

        return nil
    end

    local function Compile(Source, ChunkName)
        assert(
            type(loadstring) == "function",
            "loadstring indisponivel neste ambiente"
        )

        local Chunk,
            LoadError =
                loadstring(
                    Source,
                    ChunkName
                )

        assert(
            Chunk,
            "Falha compilando dependencia remota: "
            .. tostring(LoadError)
        )

        return Chunk
    end

    local function Load(Name, Url)
        if Destroyed then
            return false,
                "RemoteDependencies foi destruido"
        end

        if Loaded[Name] ~= nil then
            Status[Name] = "loaded"
            return true,
                Loaded[Name]
        end

        if Settings.Enabled == false then
            Status[Name] = "disabled"
            return false,
                "Carregamento remoto esta desativado em Config.RemoteDependencies.Enabled"
        end

        local HttpGet =
            GetHttpGet()

        if not HttpGet then
            Status[Name] = "HttpGet unavailable"
            return false,
                "game:HttpGet indisponivel"
        end

        local Success,
            Result =
                xpcall(function()
                    assert(
                        type(Url) == "string"
                        and Url ~= "",
                        "URL remota invalida"
                    )

                    local Source =
                        HttpGet(Url)

                    assert(
                        type(Source) == "string"
                        and #Source > 0,
                        "Dependencia remota retornou conteudo vazio"
                    )

                    local Chunk =
                        Compile(
                            Source,
                            "@newz/remote/"
                            .. Name
                        )

                    return Chunk()
                end, function(Error)
                    if
                        debug
                        and type(debug.traceback)
                            == "function"
                    then
                        return debug.traceback(
                            tostring(Error),
                            2
                        )
                    end

                    return tostring(Error)
                end)

        if not Success then
            Status[Name] =
                "error: "
                .. tostring(Result)

            return false,
                Result
        end

        Loaded[Name] = Result
        Status[Name] = "loaded"

        return true,
            Result
    end

    local Controller = {}

    function Controller.LoadStellar()
        return Load(
            "Stellar",
            Settings.StellarUrl
            or "https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Stellar/Library.lua"
        )
    end

    function Controller.LoadSensoryESP()
        return Load(
            "SensoryESP",
            Settings.SensoryESPUrl
            or "https://raw.githubusercontent.com/rthusrtghdfhtyjkehrfh/sensoryESP/main/ESP.lua"
        )
    end

    function Controller.LoadAll()
        local StellarOk,
            StellarResult =
                Controller.LoadStellar()

        if not StellarOk then
            return false,
                "Stellar: "
                .. tostring(StellarResult)
        end

        local ESPok,
            ESPResult =
                Controller.LoadSensoryESP()

        if not ESPok then
            return false,
                "sensoryESP: "
                .. tostring(ESPResult)
        end

        return true,
            {
                Stellar = StellarResult,
                SensoryESP = ESPResult,
            }
    end

    function Controller.Get(Name)
        return Loaded[Name]
    end

    function Controller.GetStatus(Name)
        if Name ~= nil then
            return Status[Name]
        end

        return {
            Stellar = Status.Stellar,
            SensoryESP = Status.SensoryESP,
        }
    end

    function Controller.Destroy()
        if Destroyed then
            return
        end

        Destroyed = true

        for Name,
            Module in pairs(Loaded)
        do
            if
                type(Module) == "table"
                and type(Module.Unload)
                    == "function"
            then
                pcall(
                    Module.Unload,
                    Module
                )
            end

            Loaded[Name] = nil
        end
    end

    return Controller
end

return RemoteDependencies
