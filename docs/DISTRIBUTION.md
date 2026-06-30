# Distribution & auto-update

Ship builds to your girlfriend via **GitHub Releases** + a small **Windows launcher** that downloads and updates automatically.

## Overview

| Piece | Purpose |
|-------|---------|
| `version.json` | Version you bump when you want a named release |
| `.github/workflows/build-release.yml` | Builds Windows `.exe`, zips it, publishes to GitHub Releases |
| `tools/launcher/Play-MazeWars.bat` | What she double-clicks — checks for updates, installs, runs |

Every push to **`main`** rebuilds and updates the **`latest`** release on GitHub.

## One-time setup (you)

### 1. Create the GitHub repo

```powershell
cd "k:\Maze Wars"
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/kylelandon/maze-wars.git
git push -u origin main
```

Use a **public** repo so the launcher can download releases without a token.

### 2. Configure the launcher

Edit `tools/launcher/config.json`:

```json
{
  "github_owner": "YOUR_GITHUB_USERNAME",
  "github_repo": "maze-wars",
  "asset_name": "MazeWars-win64.zip",
  "executable": "MazeWars.exe",
  "install_dir_name": "MazeWars"
}
```

### 3. Wait for the first build

After pushing to `main`:

1. Open GitHub → **Actions** → wait for **Build Windows Release** to finish.
2. Open **Releases** — you should see **Latest Build** with `MazeWars-win64.zip`.

You can also trigger a build manually: **Actions** → **Build Windows Release** → **Run workflow**.

### 4. Give her the launcher (once)

Zip and send **only** the launcher folder:

```
tools/launcher/
  Play-MazeWars.bat      ← she double-clicks this
  Play-MazeWars.ps1
  config.json            ← with your repo filled in
```

She does **not** need Godot installed. The game installs to:

`%LOCALAPPDATA%\MazeWars\`

## Her workflow

1. Double-click **`Play-MazeWars.bat`**
2. Launcher checks GitHub for the newest build
3. Downloads / updates if needed
4. Starts the game

Next time you push to `main`, she runs the same `.bat` and gets the new build automatically.

## Your workflow

1. Make changes locally
2. Optionally bump `version.json` (for display in the main menu)
3. Commit and push to `main`
4. GitHub Actions builds and updates the release (1–3 minutes)
5. Tell her to run the launcher again (or she can just run it — it always checks)

### Manual version bump

`version.json`:

```json
{
  "version": "0.1.1",
  "display_name": "0.1.1"
}
```

Also set in Godot **Project → Project Settings → Application → Config → Version** (`project.godot` → `config/version`).

## Local export (optional)

If you want to test the exported `.exe` on your machine:

```powershell
# Godot 4.7 on PATH, or use full path like run_game.bat
godot --headless --export-release "Windows Desktop" build/MazeWars.exe
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Launcher says repo not found | Check `config.json` owner/repo spelling; repo must be **public** |
| No release yet | Push to `main` or run workflow manually; check **Actions** tab for errors |
| Windows blocks script | She should use `.bat`, not `.ps1` directly (bypasses execution policy) |
| Firewall / antivirus | Allow download from `github.com` |
| Private repo | Needs a GitHub token in the launcher (not implemented — use public repo for now) |

## Future improvements

- Private repo support (read-only GitHub token in config)
- itch.io butler channel (built-in updater app)
- In-game “Update available” button that opens the launcher
