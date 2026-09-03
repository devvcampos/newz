-- Optional server-side companion for Config.RemoteBridge.
-- Place this script in ServerScriptService in your own experience.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Folder = ReplicatedStorage:FindFirstChild("NewzRemotes")

if not Folder then
    Folder = Instance.new("Folder")
    Folder.Name = "NewzRemotes"
    Folder.Parent = ReplicatedStorage
end

local ActionRemote = Folder:FindFirstChild("Action")

if not ActionRemote then
    ActionRemote = Instance.new("RemoteEvent")
    ActionRemote.Name = "Action"
    ActionRemote.Parent = Folder
end

ActionRemote.OnServerEvent:Connect(function(Player, Action, Payload)
    if type(Action) ~= "string" then
        return
    end

    if Action == "Ping" then
        print(
            "[Newz RemoteBridge] Ping from",
            Player.Name,
            Payload
        )
        return
    end

    -- Add only server-authorized developer actions here.
    -- Keep gameplay validation on the server.
end)
