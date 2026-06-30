class_name MWSectionLabel
extends HBoxContainer

const MW := preload("res://theme/maze_wars_colors.gd")

## Figma section divider with centered Rajdhani title.


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)


func setup(title: String) -> void:
	for child in get_children():
		child.queue_free()
	add_child(_make_line())
	var label := Label.new()
	label.text = title.to_upper()
	UIStyles.style_label(label, "section")
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MW.CYAN_DIM)
	add_child(label)
	add_child(_make_line())


func _make_line() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(48, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color(MW.CYAN, 0.18)
	return line
