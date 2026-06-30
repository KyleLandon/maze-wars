extends Node

## Central Maze Wars UI styling — Figma theme + SVG nine-patch assets.

const THEME := preload("res://theme/maze_wars_theme.tres")
const MW := preload("res://theme/maze_wars_colors.gd")

const TEX_PANEL := preload("res://textures/ui/panel_border.svg")
const TEX_PANEL_ORANGE := preload("res://textures/ui/panel_border_orange.svg")
const TEX_BTN_NORMAL := preload("res://textures/ui/btn_primary_normal.svg")
const TEX_BTN_HOVER := preload("res://textures/ui/btn_primary_hover.svg")
const TEX_BTN_PRESSED := preload("res://textures/ui/btn_primary_pressed.svg")
const TEX_BTN_DANGER := preload("res://textures/ui/btn_danger_normal.svg")
const TEX_BTN_DANGER_HOVER := preload("res://textures/ui/btn_danger_hover.svg")
const TEX_BTN_GOLD := preload("res://textures/ui/btn_gold_normal.svg")
const TEX_BTN_GOLD_HOVER := preload("res://textures/ui/btn_gold_hover.svg")
const TEX_BTN_GOLD_PRESSED := preload("res://textures/ui/btn_gold_pressed.svg")
const TEX_BTN_SECONDARY := preload("res://textures/ui/btn_secondary_normal.svg")
const TEX_BTN_SECONDARY_HOVER := preload("res://textures/ui/btn_secondary_hover.svg")
const TEX_PROGRESS_MANA := preload("res://textures/ui/progress_fill_mana.svg")
const TEX_PROGRESS_TRACK := preload("res://textures/ui/progress_track.svg")
const TEX_PROGRESS_HP := preload("res://textures/ui/progress_fill_hp.svg")
const TEX_PROGRESS_CYAN := preload("res://textures/ui/progress_fill_cyan.svg")
const TEX_PROGRESS_GOLD := preload("res://textures/ui/progress_fill_gold.svg")
const TEX_HUD_BAR_BG := preload("res://textures/ui/hud_bar_bg.svg")

const PATCH_PANEL := 14
const PATCH_BUTTON := 10
const PATCH_PROGRESS := 4

const FONT_RAJDHANI := preload("res://fonts/Rajdhani-SemiBold.ttf")
const FONT_RAJDHANI_BOLD := preload("res://fonts/Rajdhani-Bold.ttf")
const FONT_CINZEL := preload("res://fonts/Cinzel-Variable.ttf")
const FONT_ORBITRON := preload("res://fonts/Orbitron-Variable.ttf")

var _panel_style: StyleBoxTexture
var _panel_orange_style: StyleBoxTexture
var _card_disabled_style: StyleBoxFlat
var _btn_normal: StyleBoxTexture
var _btn_hover: StyleBoxTexture
var _btn_pressed: StyleBoxTexture
var _btn_danger: StyleBoxTexture
var _btn_danger_hover: StyleBoxTexture
var _btn_gold: StyleBoxTexture
var _btn_gold_hover: StyleBoxTexture
var _btn_gold_pressed: StyleBoxTexture
var _btn_secondary: StyleBoxTexture
var _btn_secondary_hover: StyleBoxTexture
var _progress_bg: StyleBoxTexture
var _themed: Theme
var _font_title: Font
var _font_title_lg: Font
var _font_numbers: Font


func _ready() -> void:
	call_deferred("_apply_root_theme")


func _apply_root_theme() -> void:
	var tree := get_tree()
	if tree and tree.root:
		tree.root.theme = get_theme()


func get_theme() -> Theme:
	if _themed == null:
		_themed = _build_themed()
	return _themed


func _build_themed() -> Theme:
	var theme := THEME.duplicate(true)
	_font_title = _var_font(FONT_CINZEL, 700.0)
	_font_title_lg = _var_font(FONT_CINZEL, 900.0)
	_font_numbers = _var_font(FONT_ORBITRON, 700.0)
	for type_name in ["Label", "RichTextLabel", "LineEdit", "ProgressBar", "TooltipLabel", "TabBar"]:
		theme.set_font("font", type_name, FONT_RAJDHANI)
	theme.set_font("font", "Button", FONT_RAJDHANI_BOLD)
	theme.set_font_size("font_size", "Label", 14)
	theme.set_font_size("font_size", "Button", 13)
	theme.set_font_size("font_size", "RichTextLabel", 14)
	return theme


func _var_font(file: FontFile, weight: float) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = file
	variation.variation_opentype = { &"wght": weight }
	return variation


func _ensure_fonts() -> void:
	if _font_title != null:
		return
	_font_title = _var_font(FONT_CINZEL, 700.0)
	_font_title_lg = _var_font(FONT_CINZEL, 900.0)
	_font_numbers = _var_font(FONT_ORBITRON, 700.0)


func _label_font_for_role(role: String) -> Font:
	_ensure_fonts()
	match role:
		"title":
			return _font_title_lg
		"heading", "section":
			return _font_title
		"chip_title":
			return FONT_RAJDHANI
		"chip_stat", "stat_value", "stat_value_gold", "stat_value_cyan", "stat", "gold", "warning":
			return _font_numbers
		_:
			return FONT_RAJDHANI


func _nine_patch(
	tex: Texture2D,
	patch: int,
	content_pad: int = -1,
	modulate: Color = Color.WHITE
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = patch
	style.texture_margin_top = patch
	style.texture_margin_right = patch
	style.texture_margin_bottom = patch
	var pad := content_pad if content_pad >= 0 else patch + 2
	style.content_margin_left = pad
	style.content_margin_top = pad
	style.content_margin_right = pad
	style.content_margin_bottom = pad
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = modulate
	return style


func make_panel_frame() -> StyleBoxTexture:
	if _panel_style == null:
		_panel_style = _nine_patch(TEX_PANEL, PATCH_PANEL, 16)
	return _panel_style


func make_panel_frame_orange() -> StyleBoxTexture:
	if _panel_orange_style == null:
		_panel_orange_style = _nine_patch(TEX_PANEL_ORANGE, PATCH_PANEL, 16)
	return _panel_orange_style


func make_card_frame(selected: bool = false, disabled: bool = false) -> StyleBox:
	if disabled:
		if _card_disabled_style == null:
			_card_disabled_style = _build_vector_card(false, true, false)
		return _card_disabled_style
	if selected:
		return _nine_patch(TEX_PANEL, PATCH_PANEL, 10, Color(1.08, 1.12, 1.18, 1.0))
	return make_panel_frame()


func make_compact_card_frame(disabled: bool = false) -> StyleBox:
	if disabled:
		if _card_disabled_style == null:
			_card_disabled_style = _build_vector_card(false, true, true)
		return _card_disabled_style
	return _nine_patch(TEX_PANEL, PATCH_PANEL, 8)


func _build_vector_card(selected: bool, disabled: bool, compact: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	if compact:
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
	else:
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
	style.set_border_width_all(1)
	style.set_border_width(SIDE_TOP, 2)
	if disabled:
		style.bg_color = Color(MW.BG, 0.55)
		style.border_color = Color(MW.TEXT_DIM, 0.35)
	elif selected:
		style.bg_color = Color(MW.CYAN, 0.12)
		style.border_color = MW.CYAN
	else:
		style.bg_color = Color(MW.SURFACE, 0.75)
		style.border_color = Color(MW.CYAN, 0.38)
	return style


func make_button_frame(hover: bool = false, pressed: bool = false) -> StyleBoxTexture:
	if pressed:
		if _btn_pressed == null:
			_btn_pressed = _nine_patch(TEX_BTN_PRESSED, PATCH_BUTTON, 14)
		return _btn_pressed
	if hover:
		if _btn_hover == null:
			_btn_hover = _nine_patch(TEX_BTN_HOVER, PATCH_BUTTON, 14)
		return _btn_hover
	if _btn_normal == null:
		_btn_normal = _nine_patch(TEX_BTN_NORMAL, PATCH_BUTTON, 14)
	return _btn_normal


func make_button(variant: String = "ghost") -> StyleBox:
	match variant:
		"gold":
			if _btn_gold == null:
				_btn_gold = _nine_patch(TEX_BTN_GOLD, PATCH_BUTTON, 14)
			return _btn_gold
		"gold_hover":
			if _btn_gold_hover == null:
				_btn_gold_hover = _nine_patch(TEX_BTN_GOLD_HOVER, PATCH_BUTTON, 14)
			return _btn_gold_hover
		"gold_pressed":
			if _btn_gold_pressed == null:
				_btn_gold_pressed = _nine_patch(TEX_BTN_GOLD_PRESSED, PATCH_BUTTON, 14)
			return _btn_gold_pressed
		"secondary":
			if _btn_secondary == null:
				_btn_secondary = _nine_patch(TEX_BTN_SECONDARY, PATCH_BUTTON, 14)
			return _btn_secondary
		"secondary_hover":
			if _btn_secondary_hover == null:
				_btn_secondary_hover = _nine_patch(TEX_BTN_SECONDARY_HOVER, PATCH_BUTTON, 14)
			return _btn_secondary_hover
		"ghost":
			var ghost := StyleBoxFlat.new()
			ghost.bg_color = Color(0, 0, 0, 0)
			ghost.set_border_width_all(0)
			ghost.content_margin_left = 10
			ghost.content_margin_right = 10
			ghost.content_margin_top = 6
			ghost.content_margin_bottom = 6
			return ghost
		"danger":
			if _btn_danger == null:
				_btn_danger = _nine_patch(TEX_BTN_DANGER, PATCH_BUTTON, 14)
			return _btn_danger
		"danger_hover":
			if _btn_danger_hover == null:
				_btn_danger_hover = _nine_patch(TEX_BTN_DANGER_HOVER, PATCH_BUTTON, 14)
			return _btn_danger_hover
		"accent", "accent_hover":
			return make_button_frame(variant == "accent_hover", false)
		"disabled":
			return _build_vector_card(false, true, false)
		"dev", "dev_hover":
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(3)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			style.set_border_width_all(1)
			if variant == "dev_hover":
				style.bg_color = Color(MW.SURFACE2, 0.75)
				style.border_color = Color(MW.TEXT_DIM, 0.5)
			else:
				style.bg_color = Color(MW.BG, 0.92)
				style.border_color = Color(MW.TEXT_DIM, 0.4)
			return style
		_:
			return make_button_frame(false, false)


func make_progress_bg() -> StyleBoxTexture:
	if _progress_bg == null:
		_progress_bg = _nine_patch(TEX_PROGRESS_TRACK, PATCH_PROGRESS, 2)
	return _progress_bg


func make_progress_fill(color: Color = BrandColors.NEON_CYAN) -> StyleBox:
	var tex := TEX_PROGRESS_CYAN
	if color.is_equal_approx(BrandColors.CRIMSON_RED) or color.is_equal_approx(MW.HP):
		tex = TEX_PROGRESS_HP
	elif color.is_equal_approx(BrandColors.METALLIC_GOLD) or color.is_equal_approx(MW.GOLD):
		tex = TEX_PROGRESS_GOLD
	elif color.is_equal_approx(BrandColors.EMBER_ORANGE):
		tex = TEX_PROGRESS_HP
	elif color.is_equal_approx(MW.MANA) or color.is_equal_approx(MW.PURPLE):
		tex = TEX_PROGRESS_MANA
	return _nine_patch(tex, PATCH_PROGRESS, 1)


func make_hud_panel(_elevated: bool = false) -> StyleBoxTexture:
	return _nine_patch(TEX_HUD_BAR_BG, PATCH_PANEL, 12)


func make_stat_card(_accent: Color = BrandColors.NEON_CYAN) -> StyleBox:
	return make_card_frame(false, false)


func make_card(selected: bool = false, _accent: Color = BrandColors.NEON_CYAN) -> StyleBox:
	return make_card_frame(selected, false)


func make_card_disabled() -> StyleBox:
	return make_card_frame(false, true)


func make_dev_panel() -> StyleBoxTexture:
	return make_panel_frame()


func apply_divider(node: Control) -> void:
	node.custom_minimum_size = Vector2(0, 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is ColorRect:
		node.color = Color(MW.CYAN, 0.22)


func apply_panel(panel: PanelContainer, elevated: bool = false) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_frame() if not elevated else make_hud_panel(true))


func apply_chip(panel: PanelContainer, accent: Color = BrandColors.NEON_CYAN) -> void:
	if accent.is_equal_approx(BrandColors.EMBER_ORANGE) or accent.is_equal_approx(MW.ORANGE):
		panel.add_theme_stylebox_override("panel", make_panel_frame_orange())
	else:
		panel.add_theme_stylebox_override("panel", make_panel_frame())


func style_label(label: Label, role: String = "body") -> void:
	var font := _label_font_for_role(role)
	if font != null:
		label.add_theme_font_override("font", font)
	match role:
		"title":
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", MW.TEXT)
		"heading":
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", MW.CYAN)
		"section":
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", MW.CYAN)
		"chip_title":
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", MW.TEXT_MID)
		"chip_stat":
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", MW.CYAN)
		"stat_value":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", MW.TEXT)
		"stat_value_gold":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", MW.GOLD)
		"stat_value_cyan":
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", MW.CYAN)
		"muted":
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", MW.TEXT_MID)
		"stat":
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", MW.TEXT)
		"gold":
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", MW.GOLD)
		"warning":
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", MW.ORANGE)
		"danger":
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", MW.RED)
		_:
			label.add_theme_color_override("font_color", MW.TEXT)


func style_button(button: Button, variant: String = "ghost") -> void:
	match variant:
		"gold":
			button.add_theme_stylebox_override("normal", make_button("gold"))
			button.add_theme_stylebox_override("hover", make_button("gold_hover"))
			button.add_theme_stylebox_override("pressed", make_button("gold_pressed"))
			button.add_theme_stylebox_override("focus", make_button("gold_hover"))
			button.add_theme_color_override("font_color", MW.GOLD)
		"secondary":
			button.add_theme_stylebox_override("normal", make_button("secondary"))
			button.add_theme_stylebox_override("hover", make_button("secondary_hover"))
			button.add_theme_stylebox_override("pressed", make_button("secondary"))
			button.add_theme_stylebox_override("focus", make_button("secondary_hover"))
			button.add_theme_color_override("font_color", MW.TEXT)
		"ghost":
			button.add_theme_stylebox_override("normal", make_button("ghost"))
			button.add_theme_stylebox_override("hover", make_button("ghost"))
			button.add_theme_stylebox_override("pressed", make_button("ghost"))
			button.add_theme_stylebox_override("focus", make_button("ghost"))
			button.add_theme_color_override("font_color", MW.TEXT_MID)
		"accent":
			button.add_theme_stylebox_override("normal", make_button_frame(false, false))
			button.add_theme_stylebox_override("hover", make_button_frame(true, false))
			button.add_theme_stylebox_override("pressed", make_button_frame(false, true))
			button.add_theme_stylebox_override("focus", make_button_frame(true, false))
			button.add_theme_color_override("font_color", MW.CYAN)
		"danger":
			button.add_theme_stylebox_override("normal", make_button("danger"))
			button.add_theme_stylebox_override("hover", make_button("danger_hover"))
			button.add_theme_stylebox_override("pressed", make_button("danger"))
			button.add_theme_stylebox_override("focus", make_button("danger_hover"))
			button.add_theme_color_override("font_color", MW.RED)
		"dev":
			button.add_theme_stylebox_override("normal", make_button("dev"))
			button.add_theme_stylebox_override("hover", make_button("dev_hover"))
			button.add_theme_stylebox_override("pressed", make_button("dev"))
			button.add_theme_stylebox_override("focus", make_button("dev_hover"))
		_:
			button.add_theme_stylebox_override("normal", make_button_frame(false, false))
			button.add_theme_stylebox_override("hover", make_button_frame(true, false))
			button.add_theme_stylebox_override("pressed", make_button_frame(false, true))
			button.add_theme_stylebox_override("focus", make_button_frame(true, false))
			button.add_theme_color_override("font_color", MW.CYAN)
	button.add_theme_font_override("font", FONT_RAJDHANI_BOLD)
	button.add_theme_stylebox_override("disabled", make_button("disabled"))
	button.add_theme_color_override("font_disabled_color", MW.TEXT_DIM)
	button.add_theme_font_size_override("font_size", 13)


func create_accent_divider(_vertical: bool = true) -> ColorRect:
	var line := ColorRect.new()
	apply_divider(line)
	return line


func make_toast_panel(toast_type: String = "info") -> StyleBoxFlat:
	var accent := MW.CYAN
	match toast_type:
		"warn", "warning":
			accent = MW.ORANGE
		"success":
			accent = Color("#22c55e")
		"danger":
			accent = MW.RED
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MW.SURFACE, 0.95)
	style.border_color = Color(accent, 0.28)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	return style


func toast_type_for_message(text: String, fallback_color: Color) -> String:
	var lower := text.to_lower()
	if lower.contains("leak") or lower.contains("defeat") or lower.contains("danger"):
		return "danger"
	if lower.contains("boss") or lower.contains("incoming") or lower.contains("sent "):
		return "warn"
	if lower.contains("victory") or lower.contains("placed") or lower.contains("eliminated"):
		return "success"
	if fallback_color.is_equal_approx(BrandColors.UI_DANGER):
		return "danger"
	if fallback_color.is_equal_approx(BrandColors.UI_SUCCESS):
		return "success"
	if fallback_color.is_equal_approx(BrandColors.UI_WARNING) or fallback_color.is_equal_approx(BrandColors.EMBER_ORANGE):
		return "warn"
	return "info"


func make_stat_tile(accent: Color = MW.CYAN) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.border_color = Color(accent, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
