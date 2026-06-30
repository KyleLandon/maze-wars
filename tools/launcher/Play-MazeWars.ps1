# Maze Wars launcher — download latest GitHub release and run the game.
# Give your girlfriend Play-MazeWars.bat (double-click). She only needs this once.

param(
    [switch]$SkipUpdate
)

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ConfigPath = Join-Path $ScriptDir "config.json"

Write-Host "Maze Wars launcher starting..." -ForegroundColor Cyan
Write-Host "Folder: $ScriptDir"

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
    $headers = @{ "User-Agent" = "MazeWars-Launcher" }
    $apiLatest = "https://api.github.com/repos/$owner/$repo/releases/latest"
    Write-Status "Checking for updates..."
    try {
        return Invoke-RestMethod -Uri $apiLatest -Headers $headers
    }
    catch {
        Write-Status "No /latest release (often pre-release) — checking all releases..."
    }

    try {
        $apiAll = "https://api.github.com/repos/$owner/$repo/releases?per_page=5"
        $releases = @(Invoke-RestMethod -Uri $apiAll -Headers $headers)
        if ($releases.Count -gt 0) {
            return $releases[0]
        }
    }
    catch {
        # Fall through to error below.
    }

    throw "Could not reach GitHub releases for $owner/$repo. Check the repo is public and a release exists with $assetName."
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
    Write-UpdaterShortcut
}

function Write-UpdaterShortcut {
    $launcherPs1 = $PSCommandPath
    $batPath = Join-Path $InstallRoot "UpdateAndRestart.bat"
    $content = "@echo off`r`ntitle Maze Wars Updater`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$launcherPs1`"`r`n"
    Set-Content -Path $batPath -Value $content -Encoding ASCII
}

try {
    $release = Get-LatestRelease
    $asset = Get-ReleaseAsset $release
    $remoteVersion = [string]$asset.updated_at
    if ([string]::IsNullOrWhiteSpace($remoteVersion)) {
        $remoteVersion = [string]$release.published_at
    }
    if ([string]::IsNullOrWhiteSpace($remoteVersion)) {
        $remoteVersion = [string]$release.tag_name
    }
    $localVersion = Get-LocalVersion

    if ($SkipUpdate) {
        Write-Status "Skipping update check."
    }
    elseif ($localVersion -ne $remoteVersion -or -not (Test-Path $GameExe)) {
        Download-And-Install $asset $remoteVersion
    }
    else {
        Write-Status "Already up to date ($localVersion)."
        Write-UpdaterShortcut
    }

    if (-not (Test-Path $GameExe)) {
        throw "Game executable not found at $GameExe"
    }

    Write-Status "Launching Maze Wars..."
    Start-Process -FilePath $GameExe -WorkingDirectory $InstallRoot
    Write-Status "Game started."
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Common fixes:"
    Write-Host "  - Extract the whole launcher folder (do not run from inside a zip)."
    Write-Host "  - Keep Play-MazeWars.bat, Play-MazeWars.ps1, and config.json together."
    Write-Host "  - Ask Kyle to confirm GitHub has a release with MazeWars-win64.zip."
    Write-Host "  - Repo: https://github.com/$owner/$repo/releases"
    exit 1
}
