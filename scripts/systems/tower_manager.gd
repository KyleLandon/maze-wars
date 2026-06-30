class_name TowerManager
extends Node

## Tower placement, upgrade, and sell orchestration.

signal tower_selected(tower: Node)
signal towers_selection_changed(towers: Array)
signal tower_deselected
signal build_mode_changed(tower_id: String)
signal placement_result(success: bool, message: String)

const TOWER_SCENE := preload("res://scenes/entities/tower.tscn")
const MAX_UNDO_SELLS := 8

var build_grid: BuildGrid
var economy: EconomyManager
var creep_spawner: CreepSpawner
var lane_root: Node3D
var owner_id: String = "player"

var selected_tower: Node = null
var selected_towers: Array = []
var build_mode_tower_id: String = ""
var towers: Array = []

var tower_damage_stats: Dictionary = {}
var _undo_sell_stack: Array = []
var owner_lane: LaneController


func setup(p_grid: BuildGrid, p_economy: EconomyManager, p_spawner: CreepSpawner) -> void:
	build_grid = p_grid
	economy = p_economy
	creep_spawner = p_spawner


func set_build_mode(tower_id: String) -> void:
	build_mode_tower_id = tower_id
	clear_selection()
	build_mode_changed.emit(tower_id)


func cancel_build_mode() -> void:
	build_mode_tower_id = ""
	build_mode_changed.emit("")


func try_place(grid: Vector2i) -> Dictionary:
	if build_mode_tower_id.is_empty():
		return { "success": false, "reason": "No build mode" }
	var check: Dictionary = build_grid.can_place(grid, build_mode_tower_id)
	if not check.get("valid", false):
		var reason := str(check.get("reason", "Invalid"))
		placement_result.emit(false, reason)
		return { "success": false, "reason": reason }
	var def: Dictionary = BalanceConfig.get_tower_def(build_mode_tower_id)
	var cost: int = int(def.get("cost", 0))
	if not economy.spend(cost, "tower"):
		placement_result.emit(false, "Not enough gold")
		return { "success": false, "reason": "Not enough gold" }
	var tower: Node3D = TOWER_SCENE.instantiate()
	var parent: Node = lane_root if lane_root else get_tree().current_scene
	parent.add_child(tower)
	tower.setup(build_mode_tower_id, grid, owner_id, creep_spawner, self)
	build_grid.register_tower(grid, tower)
	towers.append(tower)
	var message := "Placed %s" % def.get("display_name", build_mode_tower_id)
	placement_result.emit(true, message)
	return { "success": true, "reason": message }


func try_place_ai(tower_id: String, grid: Vector2i) -> bool:
	var check: Dictionary = build_grid.can_place(grid, tower_id)
	if not check.get("valid", false):
		return false
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	var cost: int = int(def.get("cost", 0))
	if economy and not economy.spend(cost, "tower"):
		return false
	var tower: Node3D = TOWER_SCENE.instantiate()
	var parent: Node = lane_root if lane_root else self
	parent.add_child(tower)
	tower.setup(tower_id, grid, owner_id, creep_spawner, self)
	build_grid.register_tower(grid, tower)
	towers.append(tower)
	return true


func select_tower_at(grid: Vector2i) -> void:
	var tower = build_grid.get_tower_at(grid)
	if tower == null:
		clear_selection()
		return
	if tower.owner_id != owner_id:
		placement_result.emit(false, "Not your tower")
		return
	_set_selection([tower])


func select_towers_in_screen_rect(camera: Camera3D, screen_rect: Rect2) -> void:
	if camera == null:
		clear_selection()
		return
	var picked: Array = []
	for cell in build_grid.towers_by_cell:
		var tower = build_grid.towers_by_cell[cell]
		if not is_instance_valid(tower) or tower.owner_id != owner_id:
			continue
		var world := LaneCoords.grid_to_world_center(cell) + Vector3(0.0, 1.5, 0.0)
		if camera.is_position_behind(world):
			continue
		var screen_pos := camera.unproject_position(world)
		if screen_rect.has_point(screen_pos):
			picked.append(tower)
	_set_selection(picked)


func select_towers_at_cells(cells: Array) -> void:
	var picked: Array = []
	for cell_value in cells:
		var cell: Vector2i = _grid_cell_from_state(cell_value)
		var tower = build_grid.get_tower_at(cell)
		if tower != null:
			picked.append(tower)
	_set_selection(picked)


func clear_selection() -> void:
	_set_selection([])


func _set_selection(picked: Array) -> void:
	for tower in selected_towers:
		if is_instance_valid(tower) and tower.has_method("set_selected"):
			tower.set_selected(false)
	selected_towers.clear()
	for tower in picked:
		if is_instance_valid(tower) and tower.owner_id == owner_id:
			selected_towers.append(tower)
	selected_tower = selected_towers[0] if selected_towers.size() > 0 else null
	for tower in selected_towers:
		if tower.has_method("set_selected"):
			tower.set_selected(true)
	if selected_towers.is_empty():
		tower_deselected.emit()
	towers_selection_changed.emit(selected_towers.duplicate())
	if selected_towers.size() == 1:
		tower_selected.emit(selected_towers[0])


func _prune_selection() -> void:
	var valid: Array = selected_towers.filter(func(t): return is_instance_valid(t))
	if valid.size() != selected_towers.size():
		_set_selection(valid)


func try_upgrade() -> Dictionary:
	if selected_towers.is_empty():
		return { "success": false, "reason": "Nothing selected" }
	var upgraded := 0
	var last_reason := "Cannot upgrade"
	for tower in selected_towers.duplicate():
		if not is_instance_valid(tower):
			continue
		var result: Dictionary = tower.try_upgrade(economy)
		last_reason = str(result.get("reason", ""))
		if result.get("success", false):
			upgraded += 1
	if upgraded > 0:
		placement_result.emit(true, "Upgraded %d tower(s)" % upgraded)
		_prune_selection()
		return { "success": true, "reason": "Upgraded %d tower(s)" % upgraded }
	placement_result.emit(false, last_reason)
	_prune_selection()
	return { "success": false, "reason": last_reason }


func try_sell() -> Dictionary:
	if selected_towers.is_empty():
		return { "success": false, "reason": "Nothing selected" }
	var sold := 0
	var last_reason := "Cannot sell"
	var undo_batch: Array = []
	var sold_cells: Array = []
	for tower in selected_towers.duplicate():
		if not is_instance_valid(tower):
			continue
		if not tower.has_method("get_undo_snapshot"):
			continue
		var snapshot: Dictionary = tower.get_undo_snapshot()
		var result: Dictionary = tower.try_sell(economy, build_grid)
		last_reason = str(result.get("reason", ""))
		if result.get("success", false):
			sold += 1
			sold_cells.append(_grid_cell_from_state(snapshot.get("grid_cell", tower.grid_cell)))
			towers.erase(tower)
			undo_batch.append(snapshot)
	if sold > 0:
		if not undo_batch.is_empty():
			_push_undo_batch(undo_batch)
		clear_selection()
		placement_result.emit(true, "Sold %d tower(s)" % sold)
		return { "success": true, "reason": "Sold %d tower(s)" % sold, "sold_cells": sold_cells }
	placement_result.emit(false, last_reason)
	return { "success": false, "reason": last_reason, "sold_cells": [] }


func try_undo_sell() -> void:
	if _undo_sell_stack.is_empty():
		placement_result.emit(false, "Nothing to undo")
		return
	var batch: Array = _undo_sell_stack.pop_back()
	var total_cost := 0
	for state: Dictionary in batch:
		var check := _can_restore_tower(state)
		if not check.get("valid", false):
			_undo_sell_stack.append(batch)
			placement_result.emit(false, str(check.get("reason", "Cannot undo")))
			return
		total_cost += int(state.get("refund", 0))
	if not economy.can_afford(total_cost):
		_undo_sell_stack.append(batch)
		placement_result.emit(false, "Not enough gold to undo sell")
		return
	economy.spend(total_cost, "undo")
	var restored: Array = []
	for state: Dictionary in batch:
		restored.append(_restore_tower(state))
	_set_selection(restored)
	placement_result.emit(true, "Restored %d tower(s)" % restored.size())


func _push_undo_batch(batch: Array) -> void:
	_undo_sell_stack.append(batch)
	while _undo_sell_stack.size() > MAX_UNDO_SELLS:
		_undo_sell_stack.pop_front()


func _can_restore_tower(state: Dictionary) -> Dictionary:
	var cell: Vector2i = _grid_cell_from_state(state.get("grid_cell", Vector2i(-1, -1)))
	if not LaneCoords.is_in_bounds(cell):
		return { "valid": false, "reason": "Invalid cell" }
	if build_grid.towers_by_cell.has(cell):
		return { "valid": false, "reason": "Tower slot occupied" }
	if build_grid.lane_grid.is_protected(cell):
		return { "valid": false, "reason": "Cannot rebuild there" }
	if not build_grid.path_manager.would_path_exist_with_block(cell):
		return { "valid": false, "reason": "Would block creep path" }
	return { "valid": true, "reason": "" }


func _restore_tower(state: Dictionary) -> Node:
	var tower: Node3D = TOWER_SCENE.instantiate()
	var parent: Node = lane_root if lane_root else get_tree().current_scene
	parent.add_child(tower)
	var cell: Vector2i = _grid_cell_from_state(state.get("grid_cell", Vector2i.ZERO))
	var tid: String = str(state.get("tower_id", "arrow"))
	tower.setup(tid, cell, owner_id, creep_spawner, self)
	if tower.has_method("restore_snapshot"):
		tower.restore_snapshot(state)
	build_grid.register_tower(cell, tower)
	towers.append(tower)
	return tower


func record_damage(tower_id: String, amount: float) -> void:
	if not tower_damage_stats.has(tower_id):
		tower_damage_stats[tower_id] = 0.0
	tower_damage_stats[tower_id] += amount


func apply_remote_place(tower_id: String, grid: Vector2i) -> void:
	if build_grid.get_tower_at(grid) != null:
		return
	var tower: Node3D = TOWER_SCENE.instantiate()
	var parent: Node = lane_root if lane_root else get_tree().current_scene
	parent.add_child(tower)
	tower.setup(tower_id, grid, owner_id, creep_spawner, self)
	if NetworkManager.is_online() and not multiplayer.is_server():
		tower.set_process(false)
	build_grid.register_tower(grid, tower)
	towers.append(tower)


func apply_remote_sell(grid: Vector2i) -> void:
	var tower = build_grid.get_tower_at(grid)
	if tower == null:
		return
	build_grid.unregister_tower(grid)
	towers.erase(tower)
	tower.queue_free()


func apply_remote_tower_state(grid: Vector2i, state: Dictionary) -> void:
	var tower = build_grid.get_tower_at(grid)
	if tower == null:
		apply_remote_place(str(state.get("tower_id", "arrow")), grid)
		tower = build_grid.get_tower_at(grid)
	if tower != null and tower.has_method("restore_snapshot"):
		tower.restore_snapshot(state)


func get_top_damage_tower() -> String:
	var best_id := ""
	var best_val := 0.0
	for key in tower_damage_stats:
		if tower_damage_stats[key] > best_val:
			best_val = tower_damage_stats[key]
			best_id = key
	return best_id


func _grid_cell_from_state(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)
