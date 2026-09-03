# Upgrade to Newz 0.6.1

This package is complete. Extract its contents over the repository root.

## New integrations

### sensoryESP remote loader

`src/Integrations/SensoryESP.lua` contains the recovered remote-loading architecture using:

```text
game:HttpGet(URL) -> loadstring(source) -> library
```

It is disabled by default:

```lua
Config.ExternalESP.Enabled = false
Config.ExternalESP.AutoLoad = false
```

The NeverLose UI remains the main Newz UI. Stellar is not loaded.

### Configured FireServer bridge

`src/Integrations/RemoteBridge.lua` resolves one explicitly configured `RemoteEvent` and exposes a normal `FireServer` call.

Default placeholder path:

```lua
Config.RemoteBridge.Path = {
    "ReplicatedStorage",
    "NewzRemotes",
    "Action",
}
```

The package includes `server/NewzRemotes.server.lua` as an optional ServerScriptService companion for the default path. You can also change the path to another RemoteEvent owned by your game before enabling the bridge.

The unknown remote used by the analyzed script was not guessed.

### Recovered-style Freecam

The Freecam was replaced with the structure supported by the recovered project evidence:

- `Enum.CameraType.Scriptable`
- `RunService.RenderStepped`
- `UserInputService.InputBegan/InputEnded`
- `UserInputService:GetMouseDelta()`
- CFrame rotation/movement
- `Enum.MouseBehavior.Default` restoration

It does not teleport or reposition the real character when disabled.

## Build

```powershell
python scripts/build.py
python scripts/check.py --require-dist
```

## Commit

```powershell
git status
git add .
git commit -m "Add sensoryESP integration and recovered freecam"
git push origin main
```
