extends Node

## Spawns crisp screen-space damage numbers over the 3D lane.

const FLOATING_DAMAGE_SCENE := preload("res://scenes/vfx/floating_damage_number.tscn")

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DamageNumberLayer"
	_layer.layer = 20
	add_child(_layer)


func spawn(world_pos: Vector3, amount: float, is_bonus: bool = false, is_reduced: bool = false) -> void:
	if _layer == null:
		return
	var label: Control = FLOATING_DAMAGE_SCENE.instantiate()
	_layer.add_child(label)
	if label.has_method("setup"):
		label.setup(world_pos, amount, is_bonus, is_reduced)
