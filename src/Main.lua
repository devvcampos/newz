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
    ESPModule.Init(
        Config
    )


local UI =
    UIModule.Init(
        Config
    )


---------------------------------------------------------
-- PROJECT
---------------------------------------------------------

local Project = {}


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

    if UI
        and type(UI.Destroy) == "function"
    then

        pcall(
            UI.Destroy
        )

    end


    if ESP
        and type(ESP.Destroy) == "function"
    then

        pcall(
            ESP.Destroy
        )

    end


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