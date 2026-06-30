# Maze Wars launcher — download latest GitHub release and run the game.
# Give your girlfriend Play-MazeWars.bat (double-click). She only needs this once.

param(
    [switch]$SkipUpdate
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Missing config.json next to the launcher." -ForegroundColor Red
    Write-Host "Copy config.json and set github_owner / github_repo."
    Read-Host "Press Enter to exit"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$owner = [string]$config.github_owner
$repo = [string]$config.github_repo
$assetName = [string]$config.asset_name
$executable = [string]$config.executable
$installName = [string]$config.install_dir_name

if ($owner -eq "YOUR_GITHUB_USERNAME" -or [string]::IsNullOrWhiteSpace($owner)) {
    Write-Host "Edit tools/launcher/config.json and set your GitHub username + repo." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$InstallRoot = Join-Path $env:LOCALAPPDATA $installName
$VersionFile = Join-Path $InstallRoot "version.txt"
$GameExe = Join-Path $InstallRoot $executable
$TempZip = Join-Path $env:TEMP "MazeWars-win64-download.zip"

function Write-Status([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Get-LocalVersion {
    if (Test-Path $VersionFile) {
        return (Get-Content $VersionFile -Raw).Trim()
    }
    return ""
}

function Save-LocalVersion([string]$Version) {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    Set-Content -Path $VersionFile -Value $Version -NoNewline
}

function Get-LatestRelease {
    $api = "https://api.github.com/repos/$owner/$repo/releases/latest"
    Write-Status "Checking for updates..."
    try {
        return Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "MazeWars-Launcher" }
    }
    catch {
        throw "Could not reach GitHub releases for $owner/$repo. Is the repo public and has a release been published?"
    }
}

function Get-ReleaseAsset($Release) {
    foreach ($asset in $Release.assets) {
        if ($asset.name -eq $assetName) {
            return $asset
        }
    }
    throw "Release '$($Release.tag_name)' has no asset named '$assetName'."
}

function Download-And-Install($Asset, [string]$RemoteVersion) {
    Write-Status "Downloading $assetName..."
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $TempZip -Headers @{ "User-Agent" = "MazeWars-Launcher" }

    Write-Status "Installing to $InstallRoot..."
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    $staging = Join-Path $env:TEMP "MazeWars-staging"
    if (Test-Path $staging) {
        Remove-Item $staging -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Expand-Archive -Path $TempZip -DestinationPath $staging -Force

    # Zip may contain files at root or inside a single subfolder.
    $payload = $staging
    $children = Get-ChildItem $staging
    if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
        $payload = $children[0].FullName
    }

    Get-ChildItem $InstallRoot -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $payload "*") -Destination $InstallRoot -Recurse -Force

    if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

    Save-LocalVersion $RemoteVersion
    Write-Status "Installed version $RemoteVersion"
}

try {
    $release = Get-LatestRelease
    $remoteVersion = [string]$release.published_at
    if ([string]::IsNullOrWhiteSpace($remoteVersion)) {
        $remoteVersion = [string]$release.tag_name
    }
    $localVersion = Get-LocalVersion

    if ($SkipUpdate) {
        Write-Status "Skipping update check."
    }
    elseif ($localVersion -ne $remoteVersion -or -not (Test-Path $GameExe)) {
        $asset = Get-ReleaseAsset $release
        Download-And-Install $asset $remoteVersion
    }
    else {
        Write-Status "Already up to date ($localVersion)."
    }

    if (-not (Test-Path $GameExe)) {
        throw "Game executable not found at $GameExe"
    }

    Write-Status "Launching Maze Wars..."
    Start-Process -FilePath $GameExe -WorkingDirectory $InstallRoot
}
catch {
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Tips:"
    Write-Host "  - Make sure you pushed to GitHub and the build workflow finished."
    Write-Host "  - The repo must be public (or use a GitHub token — not set up yet)."
    Write-Host "  - config.json must have the correct github_owner and github_repo."
    Read-Host "Press Enter to exit"
    exit 1
}
