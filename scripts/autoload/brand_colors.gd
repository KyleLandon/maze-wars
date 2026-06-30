extends Node

## Gameplay + HUD color aliases. Hex values live in theme/maze_wars_colors.gd.

const _MW := preload("res://theme/maze_wars_colors.gd")

# Brand / Figma palette
const VOID_BLACK := _MW.BG
const STEEL_GRAY := _MW.TEXT_DIM
const SILVER_METAL := _MW.TEXT
const NEON_CYAN := _MW.CYAN
const ELECTRIC_TEAL := _MW.CYAN_DIM
const EMBER_ORANGE := _MW.ORANGE
const CRIMSON_RED := _MW.RED
const PANEL_SURFACE := _MW.SURFACE
const PANEL_SURFACE_ALT := _MW.SURFACE2
const TEXT_MUTED := _MW.TEXT_MID
const METALLIC_GOLD := _MW.GOLD

# UI surfaces
const BG_DARK := VOID_BLACK
const UI_SURFACE := Color(PANEL_SURFACE, 0.94)
const UI_SURFACE_ELEVATED := Color(PANEL_SURFACE_ALT, 0.96)
const UI_PANEL := Color(PANEL_SURFACE, 0.92)
const UI_BORDER := Color(STEEL_GRAY, 0.45)
const UI_BORDER_BRIGHT := Color(STEEL_GRAY, 0.75)
const UI_TEXT := SILVER_METAL
const UI_TEXT_MUTED := TEXT_MUTED
const UI_ACCENT := NEON_CYAN
const UI_ACCENT_SOFT := Color(NEON_CYAN, 0.14)
const UI_ACCENT_SECONDARY := ELECTRIC_TEAL
const UI_GOLD := METALLIC_GOLD
const UI_GOLD_SOFT := Color(METALLIC_GOLD, 0.12)
const UI_DANGER := CRIMSON_RED
const UI_DANGER_SOFT := Color(CRIMSON_RED, 0.14)
const UI_WARNING := EMBER_ORANGE
const UI_WARNING_SOFT := Color(EMBER_ORANGE, 0.14)
const UI_SUCCESS := Color("#3DDC84")
const UI_SUCCESS_SOFT := Color("#3DDC84", 0.14)

# Lane / placement debug colors
const GRID_LINE := Color(STEEL_GRAY, 0.35)
const PATH_VALID := Color(NEON_CYAN, 0.35)
const PATH_INVALID := Color(CRIMSON_RED, 0.4)
const SPAWN_ZONE := Color(ELECTRIC_TEAL, 0.28)
const EXIT_ZONE := Color(EMBER_ORANGE, 0.28)
