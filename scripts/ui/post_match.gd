extends Control

## Post-match / defeat summary panel.

signal dismissed

const MWRewardTileScript := preload("res://scripts/ui/components/mw_reward_tile.gd")

@onready var stats_label: RichTextLabel = $Panel/Margin/VBox/StatsLabel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton
@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/Margin/VBox

var _subtitle_label: Label
var _reward_row: HBoxContainer


func _ready() -> void:
	UIStyles.apply_panel(panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.72)
	UIStyles.style_label(title_label, "title")
	UIStyles.style_button(continue_button, "gold")
	stats_label.bbcode_enabled = true
	stats_label.scroll_active = false
	stats_label.add_theme_color_override("default_color", BrandColors.UI_TEXT_MUTED)
	stats_label.add_theme_font_size_override("normal_font_size", 14)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.offset_left = -210.0
	panel.offset_right = 210.0
	_build_reward_row()


func _build_reward_row() -> void:
	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(_subtitle_label, "muted")
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_subtitle_label)
	vbox.move_child(_subtitle_label, 2)

	_reward_row = HBoxContainer.new()
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_reward_row)
	vbox.move_child(_reward_row, 3)


func show_summary(victory: bool, stats: Dictionary) -> void:
	visible = true
	title_label.text = "Victory" if victory else "Defeat"
	title_label.add_theme_color_override("font_color", BrandColors.UI_SUCCESS if victory else BrandColors.UI_DANGER)
	_subtitle_label.text = "All waves cleared" if victory else "Your core was overrun"

	_clear_reward_row()
	var reward_specs: Array = [
		["Duration", "%.0fs" % float(stats.get("duration", 0)), BrandColors.NEON_CYAN],
		["Final Wave", str(int(stats.get("final_wave", 0))), BrandColors.EMBER_ORANGE],
		["Gold Earned", str(int(stats.get("gold_earned", 0))), BrandColors.UI_GOLD],
	]
	for spec in reward_specs:
		var tile: MWRewardTile = MWRewardTileScript.create(spec[0], spec[1], spec[2])
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reward_row.add_child(tile)

	var text := "[color=#%s]Total leaks[/color]  %d\n" % [BrandColors.UI_TEXT.to_html(false), stats.get("total_leaks", 0)]
	text += "[color=#%s]Spent on towers[/color]  %d\n" % [BrandColors.UI_TEXT_MUTED.to_html(false), stats.get("spent_towers", 0)]
	text += "[color=#%s]Spent on sends[/color]  %d\n" % [BrandColors.UI_TEXT_MUTED.to_html(false), stats.get("spent_sends", 0)]
	text += "[color=#%s]Final income[/color]  %d\n" % [BrandColors.UI_TEXT.to_html(false), stats.get("final_income", 0)]
	text += "[color=#%s]Top damage tower[/color]  %s\n" % [BrandColors.UI_ACCENT.to_html(false), stats.get("top_tower", "none")]
	text += "[color=#%s]Main leak armor[/color]  %s" % [BrandColors.UI_DANGER.to_html(false), stats.get("main_leak_armor", "none")]
	stats_label.text = text


func _clear_reward_row() -> void:
	if _reward_row == null:
		return
	for child in _reward_row.get_children():
		child.queue_free()


func _on_continue_pressed() -> void:
	visible = false
	dismissed.emit()
