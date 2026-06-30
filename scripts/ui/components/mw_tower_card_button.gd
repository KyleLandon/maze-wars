class_name MWTowerCardButton
extends PanelContainer

const MW := preload("res://theme/maze_wars_colors.gd")

## Figma-style tower build card with tier pips, stats, and role label.

signal pressed(tower_id: String)

var tower_id: String = ""
var _selected: bool = false
var _affordable: bool = true
var _accent: Color = BrandColors.NEON_CYAN
var _click_button: Button


func setup(p_tower_id: String, tower_def: Dictionary, hotkey_slot: int = -1) -> void:
	tower_id = p_tower_id
	custom_minimum_size = Vector2(132, 118)
	var c: Array = tower_def.get("color", [0.5, 0.5, 0.5])
	_accent = Color(c[0], c[1], c[2])
	_build_ui(tower_def, hotkey_slot)
	_refresh_visuals()


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_visuals()


func set_affordable(can_afford: bool) -> void:
	_affordable = can_afford
	if _click_button:
		_click_button.disabled = not can_afford
	_refresh_visuals()


func _build_ui(def: Dictionary, hotkey_slot: int = -1) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_theme_constant_override("separation", 3)
	vbox.add_child(top_row)
	for i in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(6, 6)
		pip.color = _accent if i == 0 else Color(MW.BORDER_DIM)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(pip)
	if hotkey_slot > 0:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(spacer)
		var key_label := Label.new()
		key_label.text = "[%d]" % hotkey_slot
		UIStyles.style_label(key_label, "section")
		key_label.add_theme_font_size_override("font_size", 9)
		top_row.add_child(key_label)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(52, 40)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(_accent, 0.12)
	icon_style.border_color = Color(_accent, 0.28)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(4)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	vbox.add_child(icon_panel)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.color = _accent
	swatch.anchors_preset = Control.PRESET_CENTER
	swatch.anchor_left = 0.5
	swatch.anchor_right = 0.5
	swatch.anchor_top = 0.5
	swatch.anchor_bottom = 0.5
	swatch.offset_left = -9
	swatch.offset_right = 9
	swatch.offset_top = -9
	swatch.offset_bottom = 9
	icon_panel.add_child(swatch)

	var display_name: String = def.get("display_name", tower_id)
	var name_label := Label.new()
	name_label.text = display_name.replace(" Tower", "").to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(name_label, "heading")
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var role := Label.new()
	role.text = _role_for_tower(tower_id)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(role, "muted")
	role.add_theme_font_size_override("font_size", 9)
	role.add_theme_color_override("font_color", _accent)
	vbox.add_child(role)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 2)
	stats.add_theme_constant_override("v_separation", 2)
	vbox.add_child(stats)
	_add_stat_cell(stats, "DMG", int(def.get("damage", 0)))
	_add_stat_cell(stats, "RNG", int(def.get("range", 0)))

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	vbox.add_child(cost_row)
	var cost_label := Label.new()
	cost_label.text = str(int(def.get("cost", 0)))
	UIStyles.style_label(cost_label, "gold")
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_row.add_child(cost_label)
	var gold_tag := Label.new()
	gold_tag.text = "GOLD"
	UIStyles.style_label(gold_tag, "muted")
	gold_tag.add_theme_font_size_override("font_size", 9)
	cost_row.add_child(gold_tag)

	_click_button = Button.new()
	_click_button.flat = true
	_click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_click_button.pressed.connect(func(): pressed.emit(tower_id))
	add_child(_click_button)
	_click_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_button.set_offsets_preset(Control.PRESET_FULL_RECT)


func _add_stat_cell(parent: GridContainer, label_text: String, value: int) -> void:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", UIStyles.make_stat_tile(Color(0, 0, 0, 0.3)))
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(vbox)
	var title := Label.new()
	title.text = label_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(title, "muted")
	title.add_theme_font_size_override("font_size", 8)
	vbox.add_child(title)
	var val := Label.new()
	val.text = str(value)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(val, "stat")
	val.add_theme_font_size_override("font_size", 11)
	vbox.add_child(val)
	parent.add_child(cell)


func _role_for_tower(id: String) -> String:
	match id:
		"arrow":
			return "DPS"
		"cannon":
			return "SPLASH"
		"frost":
			return "SLOW"
		"magic":
			return "MAGIC"
		_:
			return "TOWER"


func _refresh_visuals() -> void:
	modulate = Color.WHITE if _affordable else Color(0.78, 0.78, 0.82, 1.0)
	if _selected:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(true, false))
	elif not _affordable:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(false, true))
	else:
		add_theme_stylebox_override("panel", UIStyles.make_card_frame(false, false))
