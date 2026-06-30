# Maze Wars launcher — download latest GitHub release and run the game.
# Give your girlfriend Play-MazeWars.bat (double-click). She only needs this once.

param(
    [switch]$SkipUpdate
)

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ConfigPath = Join-Path $ScriptDir "config.json"

$InstallRoot = Join-Path $env:LOCALAPPDATA "MazeWars"
$InstalledLauncher = Join-Path $InstallRoot "launcher\Play-MazeWars.ps1"

# After the first install, always run the launcher bundled with the game (stays current).
if ((Test-Path $InstalledLauncher) -and ($InstalledLauncher -ne $PSCommandPath)) {
    & $InstalledLauncher @PSBoundParameters
    exit $LASTEXITCODE
}

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

if (-not [string]::IsNullOrWhiteSpace($installName)) {
    $InstallRoot = Join-Path $env:LOCALAPPDATA $installName
    $InstalledLauncher = Join-Path $InstallRoot "launcher\Play-MazeWars.ps1"
}

if ($owner -eq "YOUR_GITHUB_USERNAME" -or [string]::IsNullOrWhiteSpace($owner)) {
    Write-Host "Edit tools/launcher/config.json and set your GitHub username + repo." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$GameExe = Join-Path $InstallRoot $executable
$TempZip = Join-Path $env:TEMP "MazeWars-win64-download.zip"

function Write-Status([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Get-LocalBuildStamp {
    $versionFile = Join-Path $InstallRoot "version.txt"
    if (Test-Path $versionFile) {
        $text = (Get-Content $versionFile -Raw).Trim()
        if ($text -match '^\d+\.\d+\+[a-f0-9]+') {
            return $text
        }
    }
    $stampFile = Join-Path $InstallRoot "update.stamp"
    if (Test-Path $stampFile) {
        return (Get-Content $stampFile -Raw).Trim()
    }
    return ""
}

function Get-RemoteBuildStamp($Release, $Asset) {
    $version = ""
    $sha = ""
    $body = [string]$Release.body
    if ($body -match 'Version:\s*(\S+)') {
        $version = $matches[1]
    }
    if ($body -match 'Auto-built from\s+`?([a-f0-9]{7,40})') {
        $sha = $matches[1].Substring(0, [Math]::Min(7, $matches[1].Length))
    }
    if ($version -and $sha) {
        return "${version}+${sha}"
    }
    if ($sha) {
        return $sha
    }
    return "$($Asset.id)|$($Asset.updated_at)"
}

function Save-LocalBuildStamp([string]$Stamp) {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    $stampFile = Join-Path $InstallRoot "update.stamp"
    Set-Content -Path $stampFile -Value $Stamp -NoNewline
}

function Get-LatestRelease {
    $headers = @{ "User-Agent" = "MazeWars-Launcher" }
    $apiLatest = "https://api.github.com/repos/$owner/$repo/releases/latest"
    Write-Status "Checking for updates..."
    try {
        return Invoke-RestMethod -Uri $apiLatest -Headers $headers
    }
    catch {
        Write-Status "No /latest release (often pre-release) - checking all releases..."
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

function Download-And-Install($Asset, [string]$RemoteStamp) {
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

    $payload = $staging
    $children = Get-ChildItem $staging
    if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
        $payload = $children[0].FullName
    }

    Get-ChildItem $InstallRoot -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $payload "*") -Destination $InstallRoot -Recurse -Force

    if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

    $installedStamp = Get-LocalBuildStamp
    if ([string]::IsNullOrWhiteSpace($installedStamp)) {
        Save-LocalBuildStamp $RemoteStamp
        $installedStamp = $RemoteStamp
    }
    Write-Status "Installed build $installedStamp"
    Write-UpdaterShortcut
}

function Write-UpdaterShortcut {
    $launcherPs1 = Join-Path $InstallRoot "launcher\Play-MazeWars.ps1"
    if (-not (Test-Path $launcherPs1)) {
        $launcherPs1 = $PSCommandPath
    }
    $batPath = Join-Path $InstallRoot "UpdateAndRestart.bat"
    $content = "@echo off`r`ntitle Maze Wars Updater`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$launcherPs1`"`r`n"
    Set-Content -Path $batPath -Value $content -Encoding ASCII
}

try {
    $release = Get-LatestRelease
    $asset = Get-ReleaseAsset $release
    $remoteStamp = Get-RemoteBuildStamp $release $asset
    $localStamp = Get-LocalBuildStamp

    Write-Status "Local build: $(if ($localStamp) { $localStamp } else { '(none)' })"
    Write-Status "Latest build: $remoteStamp"

    if ($SkipUpdate) {
        Write-Status "Skipping update check."
    }
    elseif ($localStamp -ne $remoteStamp -or -not (Test-Path $GameExe)) {
        Download-And-Install $asset $remoteStamp
    }
    else {
        Write-Status "Already up to date ($localStamp)."
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
    Write-Host "  - Delete %LOCALAPPDATA%\MazeWars and run again to force a fresh download."
    Write-Host "  - Repo: https://github.com/$owner/$repo/releases"
    exit 1
}
