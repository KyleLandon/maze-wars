# Maze Wars UI Kit - Godot Usage

This kit contains extracted source assets and clean reusable starter assets based on the Maze Wars brand sheet.

## Best assets to use immediately

Use these as scalable NinePatchRect textures:

- `assets/frames/frame_panel_9slice.png`
- `assets/buttons/button_frame_9slice.png`
- `assets/cards/card_frame_9slice.png`
- `assets/dividers/divider_clean_9slice.png`

The `*_source.png` files are direct extractions from the brand sheet. They may need hand cleanup, but they are useful as references or overlays.

## Suggested Godot setup

1. Copy the `ui` folder into `res://ui/`.
2. Use `NinePatchRect` for HUD frames, cards, and buttons.
3. Set patch margins around 18-28 px depending on the texture.
4. Keep main UI colors in `theme/maze_wars_colors.gd`.
5. Build reusable scenes:
   - MWStatCard.tscn
   - MWEnemySendButton.tscn
   - MWTowerCardButton.tscn
   - MWCoreHealthBar.tscn
   - MWWaveStatusPanel.tscn

## Notes

The provided brand sheet is a flattened PNG, so extraction is approximate. The clean 9-slice assets were rebuilt programmatically so they scale better in-game. For final production, rebuild the frames in Figma/Affinity/Photoshop or vector art and export transparent PNGs.
