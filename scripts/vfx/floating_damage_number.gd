extends Control

## Screen-space floating damage number (crisp 2D text over the 3D lane).

const BASE_FONT_SIZE := 20
const HIGH_ROLL_FONT_SIZE := 24
const OUTLINE_SIZE := 3

var _world_pos: Vector3 = Vector3.ZERO
var _rise_speed: float = 1.6
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(world_pos: Vector3, amount: float, is_bonus: bool, is_reduced: bool) -> void:
	_world_pos = world_pos + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	_rise_speed = 2.0 if is_bonus else 1.6

	_label = Label.new()
	_label.text = str(int(round(amount)))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(
		"font_size",
		HIGH_ROLL_FONT_SIZE if is_bonus and not is_reduced else BASE_FONT_SIZE
	)
	_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.07, 1.0))
	if is_bonus and not is_reduced:
		_label.add_theme_color_override("font_color", BrandColors.METALLIC_GOLD)
	elif is_reduced:
		_label.add_theme_color_override("font_color", BrandColors.UI_TEXT_MUTED)
	else:
		_label.add_theme_color_override("font_color", BrandColors.SILVER_METAL)

	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(72, 32)
	_update_screen_position()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.85).set_delay(0.35)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_world_pos.y += _rise_speed * delta
	_update_screen_position()


func _update_screen_position() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		visible = false
		return
	if cam.is_position_behind(_world_pos):
		visible = false
		return
	var screen_pos := cam.unproject_position(_world_pos)
	global_position = (screen_pos - size * 0.5).round()
	visible = true
