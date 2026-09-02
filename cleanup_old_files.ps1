$ErrorActionPreference = "Stop"

$obsolete = @(
    "src/Modules/CorpseIllusion.lua",
    "REMOVE_OLD_CORPSE_ACTIONS.txt"
)

foreach ($path in $obsolete) {
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removed $path"
    }
}

Write-Host "Old corpse preview/action files cleaned."
