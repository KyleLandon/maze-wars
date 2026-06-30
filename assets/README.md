# Assets

## Used at runtime

| Path | Purpose |
|------|---------|
| `ui/mazewars_logo.png` | HUD logo, project icon |
| `../textures/ui/` | SVG UI frames (see `theme/`) |
| `../fonts/` | UI fonts |
| `../theme/` | Godot theme + color constants |

## Not loaded by the game

| Path | Purpose |
|------|---------|
| `source/` | Raw PNGs for `tools/` (logo processing) |
| `MAZEWARS_FIGMA_UI/` | Figma/React design reference |
| `figma_ui_assets/` | Old export stub — use `theme/` and `textures/ui/` instead |

When adding art: put **runtime** files in `textures/` or `ui/`; put **source/reference** files in `source/` or `MAZEWARS_FIGMA_UI/`.
