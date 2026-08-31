local BASE_URL =
    "https://raw.githubusercontent.com/devvcampos/newz/main/src/"


local CacheBust =
    tostring(
        DateTime.now().UnixTimestampMillis
    )


---------------------------------------------------------
-- MODULE LOADER
---------------------------------------------------------

local function LoadModule(Path)

    local URL =
        BASE_URL
        .. Path
        .. "?cb="
        .. CacheBust


    local Source =
        game:HttpGet(URL)


    local Chunk, Error =
        loadstring(Source)


    assert(
        Chunk,
        "Falha ao carregar "
        .. Path
        .. ": "
        .. tostring(Error)
    )


    local Success, Result =
        pcall(Chunk)


    assert(
        Success,
        "Erro executando "
        .. Path
        .. ": "
        .. tostring(Result)
    )


    return Result
end


---------------------------------------------------------
-- ENVIRONMENT
---------------------------------------------------------

local Environment =
    (getgenv and getgenv())
    or _G


---------------------------------------------------------
-- REMOVE INSTANCIA ANTERIOR
---------------------------------------------------------

if
    Environment.NEWZ
    and type(Environment.NEWZ.Destroy) == "function"
then

    pcall(
        Environment.NEWZ.Destroy
    )

end


---------------------------------------------------------
-- LOAD MODULES
---------------------------------------------------------

local Config =
    LoadModule(
        "Config.lua"
    )


local ESPModule =
    LoadModule(
        "Modules/ESP.lua"
    )


local UIModule =
    LoadModule(
        "Ui.lua"
    )


---------------------------------------------------------
-- VALIDATION
---------------------------------------------------------

assert(
    type(Config) == "table",
    "Config.lua nao retornou uma tabela"
)


assert(
    type(ESPModule) == "table"
    and type(ESPModule.Init) == "function",
    "ESP.lua invalido"
)


assert(
    type(UIModule) == "table"
    and type(UIModule.Init) == "function",
    "Ui.lua invalido"
)


---------------------------------------------------------
-- INIT
---------------------------------------------------------

local ESP =
    nil


local UI =
    nil


local function CleanupController(
    Controller
)

    if
        Controller
        and type(Controller.Destroy) == "function"
    then

        pcall(
            Controller.Destroy
        )

    end

end


local function FormatInitError(
    InitError
)

    if
        debug
        and type(debug.traceback) == "function"
    then

        return debug.traceback(
            tostring(InitError),
            2
        )

    end


    return tostring(
        InitError
    )

end


local InitSuccess,
    InitError =
        xpcall(function()

            ESP =
                ESPModule.Init(
                    Config
                )


            assert(
                type(ESP) == "table",
                "ESP.Init nao retornou um controller"
            )


            UI =
                UIModule.Init(
                    Config
                )


            assert(
                type(UI) == "table",
                "UI.Init nao retornou um controller"
            )

        end,
        FormatInitError)


if not InitSuccess then

    CleanupController(
        UI
    )


    CleanupController(
        ESP
    )


    error(
        "Falha ao inicializar newz:\n"
        .. tostring(InitError),
        0
    )

end


---------------------------------------------------------
-- PROJECT
---------------------------------------------------------

local Project = {}


local ProjectDestroyed =
    false


Project.Config =
    Config


Project.ESP =
    ESP


Project.UI =
    UI


---------------------------------------------------------
-- DESTROY
---------------------------------------------------------

function Project.Destroy()

    if ProjectDestroyed then
        return
    end


    ProjectDestroyed =
        true


    CleanupController(
        UI
    )


    CleanupController(
        ESP
    )


    UI =
        nil


    ESP =
        nil


    Project.UI =
        nil


    Project.ESP =
        nil


    if
        Environment.NEWZ
        == Project
    then

        Environment.NEWZ =
            nil
    end

end


---------------------------------------------------------
-- GLOBAL PROJECT
---------------------------------------------------------

Environment.NEWZ =
    Project


return Project
