class_name LaneGrid
extends Node3D

## Visual grid floor and cell state for the lane.

signal cell_hovered(grid: Vector2i)
signal cell_clicked(grid: Vector2i, button: int)

var blocked_cells: Dictionary = {}
var protected_cells: Dictionary = {}
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	LaneCoords.load_from_config()
	_build_floor()
	_mark_protected_cells()


func _build_floor() -> void:
	_mesh_instance = MeshInstance3D.new()
	var playable := LaneCoords.playable_world_size()
	var mesh := PlaneMesh.new()
	mesh.size = playable
	_mesh_instance.mesh = mesh
	var center := LaneCoords.playable_world_center()
	_mesh_instance.position = Vector3(center.x, -0.05, center.z)
	_mesh_instance.rotation_degrees = Vector3(-90, 0, 0)
	_material = StandardMaterial3D.new()
	_material.albedo_color = BrandColors.BG_DARK.lightened(0.15)
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	_draw_grid_lines()


func _draw_grid_lines() -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BrandColors.GRID_LINE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	add_child(mi)
	var ox := LaneCoords.grid_origin_offset_x()
	var cs := LaneCoords.cell_size
	var x_min := LaneCoords.buildable_x_min()
	var x_max := LaneCoords.buildable_x_max()
	var y_min := LaneCoords.buildable_y_min()
	var y_max := LaneCoords.buildable_y_max()
	var left_x := ox + x_min * cs
	var right_x := ox + (x_max + 1) * cs
	var top_z := y_min * cs
	var bottom_z := (y_max + 1) * cs
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(x_min, x_max + 2):
		var wx := ox + x * cs
		im.surface_add_vertex(Vector3(wx, 0.02, top_z))
		im.surface_add_vertex(Vector3(wx, 0.02, bottom_z))
	for z in range(y_min, y_max + 2):
		var wz := z * cs
		im.surface_add_vertex(Vector3(left_x, 0.02, wz))
		im.surface_add_vertex(Vector3(right_x, 0.02, wz))
	im.surface_end()


func _mark_protected_cells() -> void:
	# Lane side borders are impassable and non-buildable.
	for x in [0, LaneCoords.grid_width - 1]:
		for y in range(LaneCoords.grid_height):
			protected_cells[Vector2i(x, y)] = true
	# Top/bottom margin rows match creep path bounds (outside visible build grid).
	for y in [0, LaneCoords.grid_height - 1]:
		for x in range(LaneCoords.grid_width):
			protected_cells[Vector2i(x, y)] = true
	var lane_cfg: Dictionary = BalanceConfig.lane
	for row in lane_cfg.get("protected_rows", []):
		for x in range(LaneCoords.grid_width):
			protected_cells[Vector2i(x, int(row))] = true
	for col in lane_cfg.get("protected_cols", []):
		for y in range(LaneCoords.grid_height):
			protected_cells[Vector2i(int(col), y)] = true
	protected_cells[LaneCoords.spawn_cell] = true
	protected_cells[LaneCoords.exit_cell] = true


func is_buildable(grid: Vector2i) -> bool:
	if not LaneCoords.is_in_bounds(grid):
		return false
	if protected_cells.has(grid):
		return false
	if blocked_cells.has(grid):
		return false
	return true


func is_occupied(grid: Vector2i) -> bool:
	return blocked_cells.has(grid)


func set_blocked(grid: Vector2i, blocked: bool) -> void:
	if blocked:
		blocked_cells[grid] = true
	else:
		blocked_cells.erase(grid)


func get_cell_from_ray(origin: Vector3, direction: Vector3) -> Vector2i:
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null or not hit is Vector3:
		return Vector2i(-1, -1)
	return LaneCoords.world_to_grid(hit as Vector3)


func is_protected(grid: Vector2i) -> bool:
	return protected_cells.has(grid)
