# UI Setup (Godot)

Canonical paths for the in-game UI kit:

```
res://
├── theme/
│   ├── maze_wars_theme.tres   # Applied via project.godot + UIStyles
│   └── maze_wars_colors.gd    # class_name MazeWarsColors
├── textures/ui/               # SVG nine-patches (buttons, panels, progress)
├── fonts/                       # Cinzel, Rajdhani, Orbitron
└── scripts/autoload/ui_styles.gd
```

## Apply theme

`UIStyles` sets `get_tree().root.theme` on load. `project.godot` also sets `gui/theme/custom` to `theme/maze_wars_theme.tres`.

## Colors in scripts

```gdscript
# Gameplay / HUD (aliases with lane colors)
BrandColors.NEON_CYAN

# Figma kit constants
const MW = preload("res://theme/maze_wars_colors.gd")
MW.CYAN
```

## Design reference

Original Figma/React export lives in `assets/MAZEWARS_FIGMA_UI/` for visual reference only — it is **not** loaded at runtime.
