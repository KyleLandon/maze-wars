extends CharacterBody3D

## Player builder unit for tower placement navigation.

signal moved_to(position: Vector3)

const MOVE_SPEED := 8.0

var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false


func _ready() -> void:
	target_position = global_position


func _physics_process(delta: float) -> void:
	if not is_moving:
		return
	var to_target := target_position - position
	to_target.y = 0.0
	if to_target.length() < 0.15:
		is_moving = false
		velocity = Vector3.ZERO
		return
	velocity = to_target.normalized() * MOVE_SPEED
	move_and_slide()


func move_to(world_pos: Vector3) -> void:
	target_position = Vector3(world_pos.x, position.y, world_pos.z)
	is_moving = true


func move_to_grid(grid: Vector2i) -> void:
	var pos := LaneCoords.grid_to_world_center(grid)
	move_to(pos)
