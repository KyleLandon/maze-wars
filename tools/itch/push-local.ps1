# Push a local Windows export to itch.io (manual test).
# Requires: butler CLI logged in (`butler login`), and build/ folder with MazeWars.exe

param(
    [string]$BuildPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "build")
)

$ErrorActionPreference = "Stop"
$TargetFile = Join-Path $PSScriptRoot "target.txt"
$Target = (Get-Content $TargetFile -Raw).Trim()

if ($Target -match "YOUR_") {
    Write-Host "Edit tools/itch/target.txt first (e.g. kylelandon/maze-wars:windows)" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $BuildPath "MazeWars.exe"))) {
    Write-Host "Export the game first:" -ForegroundColor Yellow
    Write-Host '  godot --headless --export-release "Windows Desktop" build/MazeWars.exe'
    exit 1
}

$VersionFile = Join-Path $BuildPath "version.txt"
if (-not (Test-Path $VersionFile)) {
    Set-Content $VersionFile "local-dev"
}

Write-Host "Pushing $BuildPath to itch.io $Target ..."
butler push $BuildPath $Target --userversion-file $VersionFile
Write-Host "Done. Open your itch page and install via the itch app to test auto-updates."
