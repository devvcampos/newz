$ErrorActionPreference = "Stop"

$obsolete = @(
    "src/Modules/CorpseActions.lua",
    "src/Modules/CorpseIllusion.lua",
    "server/CorpseActions.server.lua",
    "REMOVE_OLD_CORPSE_ACTIONS.txt"
)

foreach ($path in $obsolete) {
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removed $path"
    }
}

Write-Host "Old corpse action/illusion files cleaned."
