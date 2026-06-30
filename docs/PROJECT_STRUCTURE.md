# Maze Wars — Project Structure

Godot 4.7 tower-defense prototype. This document is the map for finding code and assets.

## Quick start

| What | Where |
|------|--------|
| Main scene | `scenes/match/match.tscn` |
| Match logic | `scripts/match/match.gd` |
| Game balance | `config/*.json` (loaded by `BalanceConfig`) |
| Player HUD | `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` |
| UI theme | `theme/maze_wars_theme.tres`, `theme/maze_wars_colors.gd` |
| UI textures | `textures/ui/*.svg` |
| Fonts | `fonts/` |

## `scripts/`

```
autoload/     Global singletons (UIStyles, BalanceConfig, BrandColors, …)
core/         Shared math/utilities (grid ↔ world: lane_coords.gd)
entities/     Tower, creep, projectile, core, builder
match/        Match controller + camera
systems/      Lanes, pathing, waves, economy, AI, placement
ui/           HUD, scoreboard, post-match, overlays
  components/ Reusable Figma-style widgets (mw_*)
vfx/          Floating damage numbers
```

### Autoloads (`project.godot`)

- **BalanceConfig** — JSON configs (`config/`)
- **BrandColors** — gameplay + UI color aliases (see `theme/maze_wars_colors.gd`)
- **GameConfig** — match session flags
- **DamageNumbers** — combat floaters
- **UIStyles** — fonts, nine-patch SVG styles, chip/panel helpers

## `scenes/`

```
entities/   3D prefabs (tower, creep, …)
match/      Main game scene
ui/         HUD, scoreboard, post-match, debug, health bar
vfx/        Damage number scene
```

## `config/`

All balance data is JSON (no code):

- `lane.json` — grid size, cell size, spawn/exit
- `towers.json`, `upgrades.json` — tower stats (**range/speed in tiles**)
- `waves.json` — creep defs + wave list (**creep speed in tiles/sec**)
- `send_packages.json`, `economy.json`, `damage_table.json`

## `theme/` and `textures/ui/`

**Canonical runtime UI.** Do not duplicate these under `assets/`.

- `theme/maze_wars_colors.gd` — `class_name MazeWarsColors`
- `theme/maze_wars_theme.tres` — global Control theme
- `textures/ui/` — SVG nine-patch sources used by `UIStyles`

## `assets/`

```
ui/              Runtime bitmaps (logo used in HUD)
source/          Raw art for tools (not loaded in-game)
MAZEWARS_FIGMA_UI/   Design reference only (React/Figma export)
figma_ui_assets/     Deprecated export stub — see docs/UI_SETUP.md
```

## `tools/`

Editor scripts (e.g. logo background removal). Not part of the game loop.

## UI components (`scripts/ui/components/`)

| Script | Used by |
|--------|---------|
| `mw_tower_card_button.gd` | HUD tower picker |
| `mw_enemy_send_button.gd` | HUD creep picker |
| `mw_section_label.gd` | Picker section headers |
| `mw_wave_timeline.gd` | HUD wave chip |
| `mw_reward_tile.gd` | Post-match summary |
| `mw_core_health_bar.gd` | HUD core HP |

## Conventions

- **Grid stats** — range, splash, creep/tower speeds in config use **tiles**; `LaneCoords` converts to world units.
- **Colors** — prefer `BrandColors.*` in gameplay/UI scripts; Figma hex source of truth is `MazeWarsColors`.
- **MW_ prefix** — Maze Wars Figma-style UI building blocks.
