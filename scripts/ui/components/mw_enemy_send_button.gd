class_name MWEnemySendButton
extends PanelContainer

const MW := preload("res://theme/maze_wars_colors.gd")

## Figma-style enemy send pack card for the HUD dock.

signal pressed(package_id: String)

var package_id: String = ""
var _unlocked: bool = true
var _affordable: bool = true
var _elite: bool = false
var _accent: Color = BrandColors.NEON_CYAN
var _click_button: Button


func setup(pkg: Dictionary, hotkey_slot: int = -1) -> void:
	package_id = str(pkg.get("id", ""))
	_elite = int(pkg.get("unlock_wave", 1)) >= 5
	_accent = BrandColors.EMBER_ORANGE if _elite else BrandColors.NEON_CYAN
	custom_minimum_size = Vector2(118, 88)
	tooltip_text = pkg.get("display_name", "")
	_build_ui(pkg, hotkey_slot)
	_refresh_visuals()


func set_state(unlocked: bool, affordable: bool) -> void:
	_unlocked = unlocked
	_affordable = affordable
	if _click_button:
		_click_button.disabled = not unlocked or not affordable
	_refresh_visuals()


func _build_ui(pkg: Dictionary, hotkey_slot: int = -1) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	var name_label := Label.new()
	name_label.text = str(pkg.get("display_name", "")).replace(" Pack", "").to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.style_label(name_label, "heading")
	name_label.add_theme_font_size_override("font_size", 11)
	if _elite:
		name_label.add_theme_color_override("font_color", MW.ORANGE)
	title_row.add_child(name_label)

	if _elite:
		var badge := Label.new()
		badge.text = "ELITE"
		UIStyles.style_label(badge, "muted")
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_color", MW.ORANGE)
		title_row.add_child(badge)

	if hotkey_slot > 0:
		var key_label := Label.new()
		key_label.text = "S+%d" % hotkey_slot
		UIStyles.style_label(key_label, "section")
		key_label.add_theme_font_size_override("font_size", 9)
		title_row.add_child(key_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 4)
	stats.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stats)
	_add_stat_cell(stats, "Cost", "%dg" % int(pkg.get("cost", 0)), BrandColors.UI_GOLD)
	_add_stat_cell(stats, "Income", "+%d" % int(pkg.get("income_gain", 0)), _accent)

	tooltip_text = "%s · %d gold · +%d income · Shift+%d" % [
		pkg.get("display_name", ""),
		int(pkg.get("cost", 0)),
		int(pkg.get("income_gain", 0)),
		hotkey_slot if hotkey_slot > 0 else 0
	]

	_click_button = Button.new()
	_click_button.flat = true
	_click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_click_button.pressed.connect(func(): pressed.emit(package_id))
	add_child(_click_button)
	_click_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_button.set_offsets_preset(Control.PRESET_FULL_RECT)


func _add_stat_cell(parent: GridContainer, label_text: String, value: String, accent: Color) -> void:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", UIStyles.make_stat_tile(accent))
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(inner)
	var title := Label.new()
	title.text = label_text.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(title, "muted")
	title.add_theme_font_size_override("font_size", 8)
	inner.add_child(title)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(val, "stat")
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", accent)
	inner.add_child(val)
	parent.add_child(cell)


func _refresh_visuals() -> void:
	if not _unlocked:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(false, true))
		modulate = Color(0.62, 0.62, 0.66, 0.82)
	elif not _affordable:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(false, true))
		modulate = Color(0.82, 0.82, 0.85, 1.0)
	elif _elite:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(true, false))
		modulate = Color(1.04, 1.0, 0.96, 1.0)
	else:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(false, false))
		modulate = Color(1.0, 1.0, 1.0, 1.0)
