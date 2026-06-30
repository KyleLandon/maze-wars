class_name MWRewardTile
extends PanelContainer

## Single reward stat tile for modals (Figma GameModal grid).


static func create(label: String, value: String, accent: Color) -> MWRewardTile:
	var tile := MWRewardTile.new()
	tile.setup(label, value, accent)
	return tile


func setup(label: String, value: String, accent: Color) -> void:
	add_theme_stylebox_override("panel", UIStyles.make_stat_tile(accent))
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(value_label, "stat_value")
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", accent)
	vbox.add_child(value_label)
	var title := Label.new()
	title.text = label.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(title, "muted")
	title.add_theme_font_size_override("font_size", 10)
	vbox.add_child(title)
