# Distribution & auto-update

Ship builds via **GitHub Releases** (launcher) and **itch.io** (itch app auto-updates). The main menu shows an **UPDATE AVAILABLE** button when a newer GitHub build exists.

## Overview

| Piece | Purpose |
|-------|---------|
| `version.json` | Display version; bump when you want |
| `distribution.json` | GitHub + itch URLs (read by game at runtime) |
| `.github/workflows/build-release.yml` | Build → GitHub Release + itch.io `windows` channel |
| `tools/launcher/Play-MazeWars.bat` | GitHub launcher — download, update, play |
| **itch.io app** | Install once; updates automatically when you push |
| **In-game button** | Main menu checks GitHub; opens launcher or itch to update |

Every push to **`main`** rebuilds and publishes to both (itch requires API key — see below).

---

## itch.io setup (recommended for your girlfriend)

The [itch.io app](https://itch.io/app) handles download + auto-update with no batch files.

### 1. Create the itch page

1. Go to [itch.io](https://itch.io) → **Dashboard** → **Create new project**
2. Kind: **Game** · Platform: **Windows**
3. Set URL slug (e.g. `maze-wars`) → page becomes `https://YOUR_NAME.itch.io/maze-wars`

### 2. Configure the repo

Edit `tools/itch/target.txt` (one line):

```
YOUR_ITCH_USERNAME/maze-wars:windows
```

Edit `distribution.json`:

```json
{
  "github_owner": "kylelandon",
  "github_repo": "maze-wars",
  "itch_url": "https://YOUR_NAME.itch.io/maze-wars",
  "itch_target": "YOUR_NAME/maze-wars:windows"
}
```

### 3. Add GitHub secret

1. itch.io → **Account settings** → **API keys** → Generate
2. GitHub repo → **Settings** → **Secrets and variables** → **Actions**
3. New secret: `ITCH_API_KEY` = your itch API key

After the next push to `main`, the workflow uploads to the `windows` channel.

### 4. Her install (one time)

1. Install the **itch.io desktop app**
2. Open your game page → **Download** / **Install**
3. Launch from her itch **Library**

When you push updates, the itch app prompts to update — no launcher needed.

### Manual itch push (optional)

```powershell
butler login
godot --headless --export-release "Windows Desktop" build/MazeWars.exe
.\tools\itch\push-local.ps1
```

---

## GitHub launcher (alternative)

### Configure launcher

`tools/launcher/config.json`:

```json
{
  "github_owner": "kylelandon",
  "github_repo": "maze-wars",
  "asset_name": "MazeWars-win64.zip",
  "executable": "MazeWars.exe",
  "install_dir_name": "MazeWars"
}
```

Send her `tools/launcher/` — she double-clicks **`Play-MazeWars.bat`**.

The launcher writes `UpdateAndRestart.bat` next to the game. The in-game **UPDATE AVAILABLE** button runs that script.

---

## GitHub Actions (what “wait for the build” means)

After `git push` to `main`:

1. Open `https://github.com/kylelandon/maze-wars/actions`
2. Click the top **Build Windows Release** run
3. Wait for a **green checkmark** (~2–5 min)
4. Check **Releases** for `MazeWars-win64.zip`

---

## In-game “Update available” button

On the main menu, the game checks GitHub’s latest release in the background.

- If `build/version.txt` (next to the `.exe`) is older than the latest release → **UPDATE AVAILABLE** appears
- Clicking it:
  1. Runs `UpdateAndRestart.bat` (GitHub launcher install), **or**
  2. Opens your **itch.io page** if no launcher is present

Works for exported builds only (not when running from the Godot editor).

---

## Your workflow

1. Change code · bump `version.json` if you want
2. `git push` to `main`
3. Wait for Actions to finish
4. She gets the update via **itch app** (automatic) or **Play-MazeWars.bat** (manual check)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| itch upload skipped in Actions | Add `ITCH_API_KEY` secret; fix `tools/itch/target.txt` |
| No UPDATE button in game | Only in exported `.exe`; needs internet; compare `version.txt` vs GitHub |
| Update button does nothing | Run `Play-MazeWars.bat` once so `UpdateAndRestart.bat` is created |
| itch game won’t update | She must use the **itch app**, not a copied `.exe` |
