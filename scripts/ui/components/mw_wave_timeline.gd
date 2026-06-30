class_name MWWaveTimeline
extends VBoxContainer

const MW := preload("res://theme/maze_wars_colors.gd")

## Dot timeline for wave progress (Figma WaveTimeline).

const DOT_NORMAL := 12
const DOT_BOSS := 18
const DOT_COMPACT := 6
const DOT_BOSS_COMPACT := 9

var _compact := false
var _title: Label
var _dots: HBoxContainer
var _footer: Label


func set_compact(enabled: bool) -> void:
	_compact = enabled
	if _title:
		_title.visible = not enabled
	add_theme_constant_override("separation", 3 if enabled else 8)
	if _footer:
		_footer.add_theme_font_size_override("font_size", 8 if enabled else 11)
	if _dots:
		_dots.add_theme_constant_override("separation", 2 if enabled else 3)


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_title = Label.new()
	_title.text = "WAVE PROGRESS"
	UIStyles.style_label(_title, "muted")
	_title.add_theme_font_size_override("font_size", 10)
	add_child(_title)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 3)
	add_child(_dots)
	_footer = Label.new()
	UIStyles.style_label(_footer, "muted")
	_footer.add_theme_font_size_override("font_size", 11)
	add_child(_footer)


func set_progress(current_wave: int, total_waves: int, preview_text: String = "") -> void:
	for child in _dots.get_children():
		child.queue_free()
	total_waves = maxi(total_waves, 1)
	var dot_normal := DOT_COMPACT if _compact else DOT_NORMAL
	var dot_boss := DOT_BOSS_COMPACT if _compact else DOT_BOSS
	for i in total_waves:
		var wave_num := i + 1
		var done := wave_num < current_wave
		var active := wave_num == current_wave
		var boss := wave_num % 5 == 0
		var dot := PanelContainer.new()
		var size := dot_boss if boss else dot_normal
		dot.custom_minimum_size = Vector2(size, size)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3 if boss else 2)
		if done:
			style.bg_color = Color(MW.ORANGE if boss else MW.CYAN, 0.65 if boss else 0.55)
			style.border_color = MW.ORANGE if boss else MW.CYAN
		elif active:
			style.bg_color = MW.CYAN
			style.border_color = MW.CYAN
			style.shadow_color = Color(MW.CYAN, 0.45)
			style.shadow_size = 4
		else:
			style.bg_color = Color(1, 1, 1, 0.04)
			style.border_color = Color(1, 1, 1, 0.08)
		style.set_border_width_all(1)
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
	var boss_in := _waves_until_boss(current_wave, total_waves)
	if preview_text.to_lower().contains("boss"):
		_footer.text = preview_text.to_upper()
	elif boss_in > 0:
		if _compact:
			_footer.text = "BOSS · %d" % boss_in
		else:
			_footer.text = "NEXT BOSS IN %d WAVE%s" % [boss_in, "" if boss_in == 1 else "S"]
	else:
		_footer.text = "FINAL WAVES"


func _waves_until_boss(current_wave: int, total_waves: int) -> int:
	for w in range(current_wave, total_waves + 1):
		if w % 5 == 0:
			return w - current_wave
	return 0
