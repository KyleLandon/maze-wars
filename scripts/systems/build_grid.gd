class_name BuildGrid
extends Node

## Grid occupancy and placement validation for towers.

signal placement_validated(grid: Vector2i, valid: bool, reason: String)
signal tower_placed(grid: Vector2i, tower_id: String)
signal tower_removed(grid: Vector2i)

var lane_grid: LaneGrid
var path_manager: PathManager
var towers_by_cell: Dictionary = {}


func setup(p_lane_grid: LaneGrid, p_path_manager: PathManager) -> void:
	lane_grid = p_lane_grid
	path_manager = p_path_manager


func can_place(grid: Vector2i, tower_id: String = "") -> Dictionary:
	if lane_grid == null or path_manager == null:
		return { "valid": false, "reason": "Systems not ready" }
	if not LaneCoords.is_in_bounds(grid):
		return { "valid": false, "reason": "Out of bounds" }
	if lane_grid.is_protected(grid):
		return { "valid": false, "reason": "Cannot build on border, spawn, or exit" }
	if towers_by_cell.has(grid):
		return { "valid": false, "reason": "Cell occupied" }
	if not path_manager.would_path_exist_with_block(grid):
		return { "valid": false, "reason": "Would block creep path" }
	return { "valid": true, "reason": "" }


func register_tower(grid: Vector2i, tower: Node) -> void:
	towers_by_cell[grid] = tower
	lane_grid.set_blocked(grid, true)
	path_manager.rebuild()
	tower_placed.emit(grid, tower.tower_id if "tower_id" in tower else "")


func unregister_tower(grid: Vector2i) -> void:
	towers_by_cell.erase(grid)
	lane_grid.set_blocked(grid, false)
	path_manager.rebuild()
	tower_removed.emit(grid)


func get_tower_at(grid: Vector2i) -> Node:
	return towers_by_cell.get(grid, null)
