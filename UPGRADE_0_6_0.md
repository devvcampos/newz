# Upgrade to Newz 0.6.0

This archive is a complete project tree, not only a patch.

## New feature modules

- `src/Features/AdvancedESP.lua`
- `src/Features/PlayerTools.lua`
- `src/Features/AimAssist.lua`
- `src/Features/CharacterFeatures.lua`
- `src/Features/FeatureInput.lua`

## Behavior reconstructed and integrated

- advanced ESP layers;
- player list/info;
- spectate controls;
- aim-assist configuration and FOV;
- Zoom (`Z`);
- local Invisible (`I`);
- Noclip (`B`);
- existing Freecam (`V`).

## Design decisions

The current NeverLose UI was retained. No Stellar UI dependency was introduced.

The sensoryESP feature set was implemented locally rather than adding a runtime `HttpGet/loadstring` dependency.

The unidentified `Tool -> RemoteEvent/RemoteFunction -> FireServer` path from the analyzed project is not included because static analysis did not establish its gameplay purpose.

The aim path is implemented as deterministic camera assistance. It does not use randomized/humanized mouse input or anti-detection techniques.

The Freecam package uses ordinary camera control and a single optional client reposition attempt on exit. It does not include movement intended to evade server or anti-cheat correction.

## Build

```powershell
python scripts/build.py
python scripts/check.py --require-dist
```
