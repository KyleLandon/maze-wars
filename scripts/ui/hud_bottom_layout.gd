class_name HudBottomLayout
extends RefCounted

## Bottom HUD layout: fixed picker slots, hint floats above, buttons per screen half.

const BOTTOM_PADDING := 8.0
const BUTTON_HEIGHT := 40.0
const GAP_PANEL_BUTTON := 10.0
const GAP_HINT_PANEL := 10.0


static func layout_bottom_ui(
	hud_size: Vector2,
	creep_button: Button,
	tower_button: Button,
	creep_panel: PanelContainer,
	tower_panel: PanelContainer,
	build_hint: Label
) -> void:
	position_action_buttons(hud_size, creep_button, tower_button)
	var panel_bottom_y: float = picker_bottom_y(hud_size)
	layout_picker_in_half(creep_panel, 0.0, hud_size.x * 0.5, panel_bottom_y)
	layout_picker_in_half(tower_panel, hud_size.x * 0.5, hud_size.x * 0.5, panel_bottom_y)
	position_build_hint(hud_size, creep_panel, tower_panel, build_hint, panel_bottom_y)


static func button_row_y(hud_size: Vector2) -> float:
	return hud_size.y - BOTTOM_PADDING - BUTTON_HEIGHT


static func picker_bottom_y(hud_size: Vector2) -> float:
	return button_row_y(hud_size) - GAP_PANEL_BUTTON


static func position_action_buttons(hud_size: Vector2, creep_button: Button, tower_button: Button) -> void:
	var y: float = button_row_y(hud_size)
	var half_w: float = hud_size.x * 0.5

	var creep_w: float = maxf(creep_button.get_combined_minimum_size().x, 140.0)
	creep_button.position = Vector2(half_w * 0.5 - creep_w * 0.5, y)
	creep_button.size = Vector2(creep_w, BUTTON_HEIGHT)

	var tower_w: float = maxf(tower_button.get_combined_minimum_size().x, 140.0)
	tower_button.position = Vector2(half_w + half_w * 0.5 - tower_w * 0.5, y)
	tower_button.size = Vector2(tower_w, BUTTON_HEIGHT)


static func layout_picker_in_half(
	panel: PanelContainer,
	half_x: float,
	half_width: float,
	panel_bottom_y: float
) -> void:
	var panel_w: float = maxf(panel.get_combined_minimum_size().x, 1.0)
	var panel_h: float = maxf(panel.get_combined_minimum_size().y, 1.0)
	var x: float = half_x + half_width * 0.5 - panel_w * 0.5
	var y: float = panel_bottom_y - panel_h
	panel.position = Vector2(x, y)
	panel.size = Vector2(panel_w, panel_h)


static func position_build_hint(
	hud_size: Vector2,
	creep_panel: PanelContainer,
	tower_panel: PanelContainer,
	build_hint: Label,
	panel_bottom_y: float
) -> void:
	if not build_hint.visible:
		return

	var tallest_panel: float = 0.0
	if creep_panel.visible:
		tallest_panel = maxf(tallest_panel, creep_panel.size.y)
	if tower_panel.visible:
		tallest_panel = maxf(tallest_panel, tower_panel.size.y)

	var hint_w: float = maxf(build_hint.get_minimum_size().x + 32.0, 280.0)
	var hint_h: float = maxf(build_hint.get_minimum_size().y, 24.0)
	var anchor_bottom: float = panel_bottom_y - tallest_panel - GAP_HINT_PANEL if tallest_panel > 0.0 else panel_bottom_y - GAP_HINT_PANEL
	build_hint.position = Vector2(hud_size.x * 0.5 - hint_w * 0.5, anchor_bottom - hint_h)
	build_hint.size = Vector2(hint_w, hint_h)


static func position_tower_info_panel(
	hud_size: Vector2,
	tower_info_panel: PanelContainer,
	tower_picker: PanelContainer,
	tower_picker_open: bool,
	panel_bottom_y: float
) -> void:
	const gap: float = 12.0
	var ref_top: float = panel_bottom_y
	if tower_picker_open:
		ref_top = minf(ref_top, tower_picker.position.y)
	var panel_h: float = maxf(tower_info_panel.size.y, 140.0)
	const panel_w: float = 322.0
	var half_w: float = hud_size.x * 0.5
	var x: float = half_w + half_w * 0.5 - panel_w * 0.5
	tower_info_panel.position = Vector2(x, ref_top - gap - panel_h)
	tower_info_panel.size = Vector2(panel_w, panel_h)
