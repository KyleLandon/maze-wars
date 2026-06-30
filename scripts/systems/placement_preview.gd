class_name PlacementPreview
extends Node3D

## Ghost preview for tower placement (green/red feedback).

var _ghost: MeshInstance3D
var _material: StandardMaterial3D
var _current_grid: Vector2i = Vector2i(-1, -1)
var _valid: bool = false
var _tower_color: Color = Color.WHITE


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(LaneCoords.cell_size * 0.9, 0.5, LaneCoords.cell_size * 0.9)
	_ghost.mesh = mesh
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = BrandColors.PATH_VALID
	_ghost.material_override = _material
	add_child(_ghost)
	visible = false


func update_preview(grid: Vector2i, valid: bool, tower_color: Color = Color.WHITE) -> void:
	_current_grid = grid
	_valid = valid
	_tower_color = tower_color
	if grid.x < 0:
		visible = false
		return
	visible = true
	var pos := LaneCoords.grid_to_world_center(grid)
	pos.y = 0.25
	position = pos
	_material.albedo_color = BrandColors.PATH_VALID if valid else BrandColors.PATH_INVALID
	if valid:
		_material.albedo_color = Color(tower_color.r, tower_color.g, tower_color.b, 0.5)


func hide_preview() -> void:
	visible = false
