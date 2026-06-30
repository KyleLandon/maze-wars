extends Control

## Screen-space drag rectangle for tower box selection.

var _drag_rect: Rect2 = Rect2()
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_drag_rect(rect: Rect2, active: bool) -> void:
	_drag_rect = rect
	_active = active
	visible = active and _drag_rect.size.length_squared() > 1.0
	queue_redraw()


func hide_drag() -> void:
	_active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_rect(_drag_rect, Color(BrandColors.NEON_CYAN, 0.12), true)
	draw_rect(_drag_rect, Color(BrandColors.NEON_CYAN, 0.75), false, 2.0)
