class_name PathManager
extends Node

## AStarGrid2D pathfinding with 3D waypoint output.

signal path_updated(waypoints: Array)

var lane_grid: LaneGrid
var astar: AStarGrid2D
var current_waypoints: Array[Vector3] = []


func setup(p_lane_grid: LaneGrid) -> void:
	lane_grid = p_lane_grid
	_init_astar()
	rebuild()


func _init_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, LaneCoords.grid_width, LaneCoords.grid_height)
	astar.cell_size = Vector2(LaneCoords.cell_size, LaneCoords.cell_size)
	astar.offset = Vector2(
		-LaneCoords.grid_width * LaneCoords.cell_size * 0.5,
		0.0
	)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


func rebuild() -> void:
	if astar == null:
		return
	astar.update()
	for x in range(LaneCoords.grid_width):
		for y in range(LaneCoords.grid_height):
			var cell := Vector2i(x, y)
			var solid := not _is_walkable(cell)
			astar.set_point_solid(cell, solid)
	current_waypoints = get_path_waypoints()
	path_updated.emit(current_waypoints)


func would_path_exist_with_block(test_cell: Vector2i) -> bool:
	var was_solid := astar.is_point_solid(test_cell) if _cell_in_astar(test_cell) else false
	astar.set_point_solid(test_cell, true)
	var path := astar.get_id_path(LaneCoords.spawn_cell, LaneCoords.exit_cell)
	astar.set_point_solid(test_cell, was_solid)
	return path.size() > 0


func get_path_grid_length() -> int:
	return astar.get_id_path(LaneCoords.spawn_cell, LaneCoords.exit_cell).size()


func get_path_grid_length_with_extra_block(cell: Vector2i) -> int:
	var was_solid := astar.is_point_solid(cell) if _cell_in_astar(cell) else false
	astar.set_point_solid(cell, true)
	var length := astar.get_id_path(LaneCoords.spawn_cell, LaneCoords.exit_cell).size()
	astar.set_point_solid(cell, was_solid)
	return length


func get_path_waypoints() -> Array[Vector3]:
	var grid_path := astar.get_id_path(LaneCoords.spawn_cell, LaneCoords.exit_cell)
	var waypoints: Array[Vector3] = []
	for cell: Vector2i in grid_path:
		var wp := LaneCoords.grid_to_world_center(cell)
		wp.y = 0.5
		waypoints.append(wp)
	return waypoints


func _is_walkable(cell: Vector2i) -> bool:
	if not LaneCoords.is_creep_path_cell(cell):
		return false
	if lane_grid == null:
		return true
	# Creeps walk through empty cells; towers block the path and shape the maze.
	return not lane_grid.is_occupied(cell)


func _cell_in_astar(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < LaneCoords.grid_width and cell.y >= 0 and cell.y < LaneCoords.grid_height
