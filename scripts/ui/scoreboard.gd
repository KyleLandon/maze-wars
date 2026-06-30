extends Control

## Hold Tab scoreboard — live stats for every lane in the match.

const MW := preload("res://theme/maze_wars_colors.gd")

@onready var stats_label: RichTextLabel = $Panel/Margin/VBox/StatsLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyles.apply_panel($Panel, true)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	$Panel/Margin/VBox/TitleLabel.text = "SCOREBOARD"
	UIStyles.style_label(hint_label, "muted")
	hint_label.text = "HOLD TAB"
	stats_label.bbcode_enabled = true
	stats_label.scroll_active = false
	stats_label.fit_content = true
	stats_label.add_theme_color_override("default_color", BrandColors.UI_TEXT)
	stats_label.add_theme_font_size_override("normal_font_size", 14)


func show_board(rows: Array) -> void:
	visible = true
	stats_label.text = _format_rows(rows)


func hide_board() -> void:
	visible = false


func _format_rows(rows: Array) -> String:
	if rows.is_empty():
		return "[color=#%s]No player data[/color]" % BrandColors.UI_TEXT_MUTED.to_html(false)
	var text := "[color=#%s]%s%s%s%s%s%s[/color]\n" % [
		BrandColors.UI_TEXT_MUTED.to_html(false),
		_col("#", 4),
		_col("PLAYER", 18),
		_col("KILLS", 8),
		_col("INCOME", 12),
		_col("GOLD", 12),
		_col("CORE", 10)
	]
	var rank := 0
	for row in rows:
		if row is not Dictionary:
			continue
		rank += 1
		var eliminated: bool = row.get("eliminated", false)
		var is_player: bool = row.get("is_player", false)
		var name_text := str(row.get("name", "Unknown")).to_upper()
		if eliminated:
			name_text += " (OUT)"
		var rank_text := _rank_label(rank)
		var rank_color := _rank_color(rank) if not eliminated else BrandColors.UI_TEXT_MUTED
		var name_color := BrandColors.UI_TEXT_MUTED if eliminated else (
			BrandColors.NEON_CYAN if is_player else BrandColors.UI_TEXT
		)
		var stat_color := BrandColors.UI_TEXT_MUTED if eliminated else BrandColors.UI_TEXT
		var gold_color := BrandColors.UI_TEXT_MUTED if eliminated else BrandColors.UI_GOLD
		var core_current := int(row.get("core_current", 0))
		var core_max := int(row.get("core_max", 0))
		var core_color := BrandColors.UI_TEXT_MUTED if eliminated else (
			BrandColors.UI_DANGER if core_max > 0 and core_current <= int(core_max * 0.35) else BrandColors.UI_TEXT
		)
		var prefix := ""
		if is_player and not eliminated:
			prefix = "[bgcolor=#%s22]" % BrandColors.NEON_CYAN.to_html(false)
		var suffix := "[/bgcolor]" if is_player and not eliminated else ""
		text += "%s[color=#%s]%s[/color][color=#%s]%s[/color][color=#%s]%s[/color][color=#%s]%s[/color][color=#%s]%s[/color][color=#%s]%s[/color]%s\n" % [
			prefix,
			rank_color.to_html(false),
			_col(rank_text, 4),
			name_color.to_html(false),
			_col(name_text, 18),
			stat_color.to_html(false),
			_col(str(int(row.get("kills", 0))), 8),
			stat_color.to_html(false),
			_col(str(int(row.get("total_income", 0))), 12),
			gold_color.to_html(false),
			_col(str(int(row.get("total_gold", 0))), 12),
			core_color.to_html(false),
			_col("%d/%d" % [core_current, core_max], 10),
			suffix
		]
	return text


func _rank_label(rank: int) -> String:
	match rank:
		1:
			return "1"
		2:
			return "2"
		3:
			return "3"
		_:
			return str(rank)


func _rank_color(rank: int) -> Color:
	match rank:
		1:
			return MW.GOLD
		2:
			return Color("#a0aec0")
		3:
			return Color("#cd7f32")
		_:
			return MW.TEXT_DIM


func _col(text: String, width: int) -> String:
	if text.length() > width:
		return text.substr(0, width)
	return text.rpad(width, " ")
