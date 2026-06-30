extends Camera3D

## Top-down angled camera with pan and zoom.

const MIN_ZOOM := 28.0
const MAX_ZOOM := 90.0
const PAN_SPEED := 30.0
const ZOOM_SPEED := 6.0

var _zoom_distance: float = 52.0
var _pan_offset: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	LaneCoords.load_from_config()
	var lane_center := LaneCoords.grid_to_world_center(LaneCoords.grid_center_cell())
	_pan_offset = lane_center
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed):
			_dragging = event.pressed
			_last_mouse = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_distance = maxf(_zoom_distance - ZOOM_SPEED, MIN_ZOOM)
			_update_transform()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_distance = minf(_zoom_distance + ZOOM_SPEED, MAX_ZOOM)
			_update_transform()
	if event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _last_mouse
		_last_mouse = event.position
		var right := global_transform.basis.x
		var forward := -global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		right = right.normalized()
		forward = forward.normalized()
		_pan_offset -= right * delta.x * 0.05 + forward * delta.y * 0.05
		_update_transform()


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move != Vector3.ZERO:
		_pan_offset += move.normalized() * PAN_SPEED * delta
		_update_transform()


func set_lane_center(center: Vector3) -> void:
	_pan_offset = Vector3(center.x, 0.0, center.z)
	_update_transform()


func _update_transform() -> void:
	var target := _pan_offset + Vector3(0, 0.5, 0)
	global_position = target + Vector3(0, _zoom_distance * 0.85, _zoom_distance * 0.55)
	look_at(target, Vector3.UP)
