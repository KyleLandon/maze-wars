# Maze Wars launcher - download latest GitHub release and run the game.
# Incremental sync: only copies changed files and removes files dropped from the release.

param(
    [switch]$SkipUpdate,
    [switch]$ForceFullReinstall
)

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ConfigPath = Join-Path $ScriptDir "config.json"

$InstallRoot = Join-Path $env:LOCALAPPDATA "MazeWars"
$InstalledLauncher = Join-Path $InstallRoot "launcher\Play-MazeWars.ps1"
$ManifestFileName = "install.manifest.json"
# Launcher-owned metadata - never delete during stale-file cleanup.
$ProtectedRelativePaths = @(
    $ManifestFileName,
    "UpdateAndRestart.bat",
    "update.stamp",
    "version.txt"
)

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

function Normalize-RelativePath([string]$Path) {
    return ($Path -replace '\\', '/').TrimStart('./')
}

function Get-Sha256([string]$Path) {
    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $hash.Hash.ToLowerInvariant()
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
    if ([string]::IsNullOrWhiteSpace($Stamp)) {
        return
    }
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    $stampFile = Join-Path $InstallRoot "update.stamp"
    Set-Content -Path $stampFile -Value $Stamp -NoNewline
    $versionFile = Join-Path $InstallRoot "version.txt"
    Set-Content -Path $versionFile -Value $Stamp -NoNewline
}

function Get-InstallManifestPath {
    return Join-Path $InstallRoot $ManifestFileName
}

function Load-InstallManifest {
    $path = Get-InstallManifestPath
    if (-not (Test-Path $path)) {
        return @{}
    }
    try {
        $raw = Get-Content $path -Raw | ConvertFrom-Json
        $map = @{}
        foreach ($prop in $raw.PSObject.Properties) {
            $map[$prop.Name] = [string]$prop.Value
        }
        return $map
    }
    catch {
        return @{}
    }
}

function Save-InstallManifest([hashtable]$Manifest) {
    $path = Get-InstallManifestPath
    $sorted = [ordered]@{}
    foreach ($key in ($Manifest.Keys | Sort-Object)) {
        $sorted[$key] = $Manifest[$key]
    }
    ($sorted | ConvertTo-Json -Depth 3) | Set-Content -Path $path -Encoding UTF8
}

function Get-ReleaseManifest([string]$PayloadRoot) {
    $bundled = Join-Path $PayloadRoot "manifest.json"
    if (Test-Path $bundled) {
        Write-Status "Using release manifest..."
        $raw = Get-Content $bundled -Raw | ConvertFrom-Json
        $map = @{}
        foreach ($prop in $raw.PSObject.Properties) {
            $key = Normalize-RelativePath $prop.Name
            $map[$key] = [string]$prop.Value
        }
        return $map
    }

    Write-Status "Building file manifest from download..."
    $map = @{}
    $files = Get-ChildItem -Path $PayloadRoot -File -Recurse
    foreach ($file in $files) {
        $rel = Normalize-RelativePath $file.FullName.Substring($PayloadRoot.Length)
        if ($rel -eq "manifest.json") {
            continue
        }
        $map[$rel] = Get-Sha256 $file.FullName
    }
    return $map
}

function Stop-RunningGame {
    $processes = @(Get-Process -Name "MazeWars" -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return
    }
    Write-Status "Closing Maze Wars before updating..."
    $processes | Stop-Process -Force
    Start-Sleep -Seconds 1
}

function Copy-ReleaseFile([string]$SourcePath, [string]$DestPath) {
    $destDir = Split-Path -Parent $DestPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    if ((Test-Path $DestPath) -and ($DestPath -like "*.exe")) {
        $backup = "$DestPath.old"
        if (Test-Path $backup) {
            Remove-Item $backup -Force
        }
        try {
            Rename-Item -Path $DestPath -NewName (Split-Path -Leaf $backup) -Force
        }
        catch {
            Remove-Item $DestPath -Force -ErrorAction SilentlyContinue
        }
    }
    Copy-Item -Path $SourcePath -Destination $DestPath -Force
    $oldExe = "$DestPath.old"
    if (Test-Path $oldExe) {
        Remove-Item $oldExe -Force -ErrorAction SilentlyContinue
    }
}

function Remove-EmptyDirectories([string]$Root) {
    if (-not (Test-Path $Root)) {
        return
    }
    $dirs = Get-ChildItem -Path $Root -Directory -Recurse | Sort-Object FullName -Descending
    foreach ($dir in $dirs) {
        if (-not (Get-ChildItem -Path $dir.FullName -Force | Select-Object -First 1)) {
            Remove-Item $dir.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Sync-InstallFromStaging([string]$PayloadRoot, [hashtable]$RemoteManifest, [hashtable]$LocalManifest) {
    $stats = @{
        copied = 0
        skipped = 0
        removed = 0
    }

    foreach ($rel in ($RemoteManifest.Keys | Sort-Object)) {
        $src = Join-Path $PayloadRoot ($rel -replace '/', '\')
        $dst = Join-Path $InstallRoot ($rel -replace '/', '\')
        if (-not (Test-Path $src)) {
            continue
        }

        $remoteHash = $RemoteManifest[$rel]
        $knownHash = ""
        if ($LocalManifest.ContainsKey($rel)) {
            $knownHash = $LocalManifest[$rel]
        }

        $needsCopy = $ForceFullReinstall -or -not (Test-Path $dst) -or ($knownHash -ne $remoteHash)
        if (-not $needsCopy -and (Test-Path $dst)) {
            $stats.skipped++
            continue
        }

        Copy-ReleaseFile $src $dst
        $stats.copied++
    }

    $remoteKeys = [System.Collections.Generic.HashSet[string]]::new([string[]]$RemoteManifest.Keys)
    foreach ($rel in ($LocalManifest.Keys | Sort-Object)) {
        if ($remoteKeys.Contains($rel)) {
            continue
        }
        if ($ProtectedRelativePaths -contains $rel) {
            continue
        }
        $target = Join-Path $InstallRoot ($rel -replace '/', '\')
        if (Test-Path $target) {
            Remove-Item $target -Force -Recurse -ErrorAction SilentlyContinue
            $stats.removed++
        }
    }

    Get-ChildItem -Path $InstallRoot -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $rel = Normalize-RelativePath $_.FullName.Substring($InstallRoot.Length)
        if ($remoteKeys.Contains($rel)) {
            return
        }
        if ($ProtectedRelativePaths -contains $rel) {
            return
        }
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        $stats.removed++
    }

    Remove-EmptyDirectories $InstallRoot
    Save-InstallManifest $RemoteManifest
    return $stats
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

function Test-ZipFile([string]$Path) {
    if (-not (Test-Path $Path)) {
        return $false
    }
    $length = (Get-Item $Path).Length
    if ($length -lt 22) {
        return $false
    }
    $bytes = [byte[]](Get-Content -Path $Path -Encoding Byte -TotalCount 2)
    return ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)
}

function Download-ReleaseAsset($Asset) {
    $expectedSize = [long]$Asset.size
    $downloadUrl = [string]$Asset.url
    if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
        $downloadUrl = [string]$Asset.browser_download_url
    }

    $headers = @{
        "User-Agent" = "MazeWars-Launcher"
        "Accept"     = "application/octet-stream"
    }

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if (Test-Path $TempZip) {
            Remove-Item $TempZip -Force
        }

        $sizeLabel = if ($expectedSize -gt 0) {
            ([math]::Round($expectedSize / 1MB, 1)).ToString() + " MB"
        }
        else {
            "unknown size"
        }
        Write-Status "Downloading $assetName ($sizeLabel) - attempt $attempt of $maxAttempts..."

        try {
            Invoke-WebRequest `
                -Uri $downloadUrl `
                -OutFile $TempZip `
                -Headers $headers `
                -UseBasicParsing `
                -MaximumRedirection 10 `
                -TimeoutSec 600
        }
        catch {
            if ($attempt -ge $maxAttempts) {
                throw "Download failed: $($_.Exception.Message)"
            }
            Write-Status "Download failed. Retrying..."
            Start-Sleep -Seconds 2
            continue
        }

        if (-not (Test-ZipFile $TempZip)) {
            if ($attempt -ge $maxAttempts) {
                throw "Downloaded file is not a valid zip. Check your connection or try again."
            }
            Write-Status "Download corrupt or incomplete. Retrying..."
            Start-Sleep -Seconds 2
            continue
        }

        if ($expectedSize -gt 0) {
            $actualSize = (Get-Item $TempZip).Length
            if ($actualSize -ne $expectedSize) {
                if ($attempt -ge $maxAttempts) {
                    throw "Download incomplete ($actualSize of $expectedSize bytes)."
                }
                Write-Status "Download incomplete ($actualSize / $expectedSize bytes). Retrying..."
                Start-Sleep -Seconds 2
                continue
            }
        }

        Write-Status "Download complete."
        return
    }
}

function Download-And-Install($Asset, [string]$RemoteStamp) {
    Download-ReleaseAsset $Asset

    Write-Status "Preparing install at $InstallRoot..."
    Stop-RunningGame
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

    if ($ForceFullReinstall) {
        Write-Status "Force reinstall - clearing old install files..."
        Get-ChildItem $InstallRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -in @($ManifestFileName, "UpdateAndRestart.bat")) {
                return
            }
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $localManifest = Load-InstallManifest
    $remoteManifest = Get-ReleaseManifest $payload
    $stats = Sync-InstallFromStaging $payload $remoteManifest $localManifest

    if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

    if (-not [string]::IsNullOrWhiteSpace($RemoteStamp)) {
        Save-LocalBuildStamp $RemoteStamp
    }
    else {
        $installedVersionFile = Join-Path $InstallRoot "version.txt"
        if (Test-Path $installedVersionFile) {
            Save-LocalBuildStamp (Get-Content $installedVersionFile -Raw).Trim()
        }
    }

    $installedStamp = Get-LocalBuildStamp
    $buildLabel = if ($installedStamp) { $installedStamp } else { $RemoteStamp }
    Write-Status "Updated build $buildLabel - copied $($stats.copied), skipped $($stats.skipped), removed $($stats.removed)"
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
    elseif ($ForceFullReinstall -or $localStamp -ne $remoteStamp -or -not (Test-Path $GameExe)) {
        Download-And-Install $asset $remoteStamp
    }
    else {
        Write-Status "Already up to date ($localStamp)."
        if (-not [string]::IsNullOrWhiteSpace($remoteStamp)) {
            Save-LocalBuildStamp $remoteStamp
        }
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
    Write-Host "  - Close Maze Wars if an update failed while the game was running."
    Write-Host "  - Check your internet connection and run the launcher again."
    Write-Host "  - Run Play-MazeWars.ps1 -ForceFullReinstall for a clean reinstall."
    Write-Host "  - Repo: https://github.com/$owner/$repo/releases"
    exit 1
}
