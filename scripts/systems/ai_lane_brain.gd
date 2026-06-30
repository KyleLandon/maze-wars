extends Node

## Builds full-lane serpentine mazes, fortifies turns, then extends path length.

signal send_executed(package_name: String, hit_player: bool)

enum Phase { WALLS, FORTIFY, EXTEND }

const WALL_TOWER := "arrow"
const FORTIFY_TOWERS: Array[String] = ["arrow", "cannon", "frost", "magic"]
const WALL_ROW_STEP := 2
const WALLS_PER_TICK := 2
const FORTIFY_REFRESH_INTERVAL := 5
const MIN_PATH_GAIN := 3

var lane: Node
var send_manager: SendManager
var wave_coordinator: MatchWaveCoordinator
var enemy_lanes: Array = []

var _action_timer: float = 0.5
var _phase: Phase = Phase.WALLS
var _wall_blueprint: Array[Vector2i] = []
var _wall_index: int = 0
var _fortify_queue: Array[Vector2i] = []
var _fortify_index: int = 0
var _fortify_tower_index: int = 0
var _fortify_refresh_cooldown: int = 0
var _walls_complete: bool = false


func setup(p_lane: Node) -> void:
	lane = p_lane
	_action_timer = 0.5
	_build_wall_blueprint()


func configure_sending(p_send_manager: SendManager, p_waves: MatchWaveCoordinator, p_enemies: Array) -> void:
	send_manager = p_send_manager
	wave_coordinator = p_waves
	enemy_lanes = p_enemies


func _process(delta: float) -> void:
	if lane == null or lane.is_eliminated:
		return
	if send_manager == null or wave_coordinator == null:
		return
	_action_timer -= delta
	if _action_timer > 0.0:
		return
	_action_timer = _build_interval()
	if _should_send():
		if _try_send():
			return
	_tick_build()


func _build_interval() -> float:
	var base := float(BalanceConfig.economy.get("ai_build_interval_seconds", 3.5))
	if _phase == Phase.WALLS and not _walls_complete:
		return maxf(base * 0.45, 1.2)
	if _phase == Phase.EXTEND:
		return maxf(base * 0.7, 2.0)
	return base


func _should_send() -> bool:
	if not _walls_complete:
		return false
	var eco: EconomyManager = lane.economy
	var reserve := _gold_reserve()
	var best_pkg := _best_affordable_send(reserve)
	if best_pkg.is_empty():
		return false
	var cost := int(best_pkg.get("cost", 0))
	var income_threshold := int(BalanceConfig.economy.get("ai_send_income_threshold", 45))
	if eco.income < income_threshold:
		return eco.gold >= cost + reserve + 40
	return eco.gold >= cost + reserve + 100


func _try_send() -> bool:
	var reserve := _gold_reserve()
	var pkg := _best_affordable_send(reserve)
	if pkg.is_empty():
		return false
	var package_id: String = str(pkg.get("id", ""))
	var result: Dictionary = send_manager.purchase_for_lane(lane, enemy_lanes, package_id)
	if not result.get("success", false):
		return false
	var hit_player := false
	for target in enemy_lanes:
		if target == null or not is_instance_valid(target):
			continue
		if target.is_player and not target.is_eliminated:
			hit_player = true
			break
	var pkg_name: String = pkg.get("display_name", package_id)
	send_executed.emit(pkg_name, hit_player)
	return true


func _best_affordable_send(reserve: int) -> Dictionary:
	var current_wave := wave_coordinator.get_current_wave_number()
	var best: Dictionary = {}
	var best_score := -1.0
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		if current_wave < int(pkg.get("unlock_wave", 1)):
			continue
		var cost := int(pkg.get("cost", 0))
		if lane.economy.gold < cost + reserve:
			continue
		var income_gain := int(pkg.get("income_gain", 0))
		var score := float(income_gain) / float(max(cost, 1))
		if score > best_score:
			best_score = score
			best = pkg
	return best


func _gold_reserve() -> int:
	var base := int(BalanceConfig.economy.get("ai_min_gold_reserve", 35))
	if not _walls_complete:
		return mini(base, 15)
	return base


func _can_afford_build(tower_id: String) -> bool:
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	return lane.economy.gold >= int(def.get("cost", 0)) + _gold_reserve()


func _tick_build() -> void:
	match _phase:
		Phase.WALLS:
			if _try_place_walls_burst():
				return
			_walls_complete = true
			_phase = Phase.FORTIFY
			_refresh_fortify_queue()
		Phase.FORTIFY:
			if _try_place_fortify():
				return
			_phase = Phase.EXTEND
		Phase.EXTEND:
			if _try_extend_maze():
				return
			if _fortify_refresh_cooldown <= 0:
				_refresh_fortify_queue()
				_fortify_refresh_cooldown = FORTIFY_REFRESH_INTERVAL
			else:
				_fortify_refresh_cooldown -= 1
			_try_place_fortify()


func _build_wall_blueprint() -> void:
	_wall_blueprint.clear()
	_wall_index = 0
	_walls_complete = false
	var x_min := LaneCoords.buildable_x_min()
	var x_max := LaneCoords.buildable_x_max()
	var row_idx := 0
	var y := LaneCoords.buildable_y_min() + 1
	var y_max := LaneCoords.buildable_y_max()
	while y <= y_max:
		var gap_on_right := row_idx % 2 == 0
		var gap_x := x_max if gap_on_right else x_min
		for x in range(x_min, x_max + 1):
			if x == gap_x:
				continue
			var cell := Vector2i(x, y)
			if lane.lane_grid.is_protected(cell):
				continue
			_wall_blueprint.append(cell)
		row_idx += 1
		y += WALL_ROW_STEP
	_wall_blueprint.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)


func _try_place_walls_burst() -> bool:
	if not _can_afford_build(WALL_TOWER):
		return _wall_index < _wall_blueprint.size()
	var placed := 0
	while _wall_index < _wall_blueprint.size() and placed < WALLS_PER_TICK:
		var cell: Vector2i = _wall_blueprint[_wall_index]
		_wall_index += 1
		if lane.tower_manager.try_place_ai(WALL_TOWER, cell):
			placed += 1
	return placed > 0 or _wall_index < _wall_blueprint.size()


func _refresh_fortify_queue() -> void:
	_fortify_queue.clear()
	_fortify_index = 0
	var path_cells := _get_path_cell_set()
	var turn_cells := _get_turn_cells()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var seen: Dictionary = {}
	for turn in turn_cells:
		for d in dirs:
			var spot: Vector2i = turn + d
			if path_cells.has(_cell_key(spot)):
				continue
			var key := _cell_key(spot)
			if seen.has(key):
				continue
			seen[key] = true
			var check: Dictionary = lane.build_grid.can_place(spot, WALL_TOWER)
			if check.get("valid", false):
				_fortify_queue.append(spot)
	_fortify_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)


func _try_place_fortify() -> bool:
	while _fortify_index < _fortify_queue.size():
		var cell: Vector2i = _fortify_queue[_fortify_index]
		_fortify_index += 1
		var tower_id: String = _pick_fortify_tower(cell)
		if not _can_afford_build(tower_id):
			continue
		if lane.tower_manager.try_place_ai(tower_id, cell):
			return true
	return false


func _pick_fortify_tower(cell: Vector2i) -> String:
	var turns := _get_turn_cells()
	for turn in turns:
		if LaneCoords.grid_tile_distance(turn, cell) <= 1:
			return FORTIFY_TOWERS[_fortify_tower_index % FORTIFY_TOWERS.size()]
	return WALL_TOWER


func _try_extend_maze() -> bool:
	if not _can_afford_build(WALL_TOWER):
		return false
	var pm: PathManager = lane.path_manager
	var base_len := pm.get_path_grid_length()
	var best_cell := Vector2i(-1, -1)
	var best_score := -1.0
	for y in range(LaneCoords.buildable_y_min(), LaneCoords.buildable_y_max() + 1):
		for x in range(LaneCoords.buildable_x_min(), LaneCoords.buildable_x_max() + 1):
			var cell := Vector2i(x, y)
			var check: Dictionary = lane.build_grid.can_place(cell, WALL_TOWER)
			if not check.get("valid", false):
				continue
			var new_len := pm.get_path_grid_length_with_extra_block(cell)
			var gain := new_len - base_len
			if gain < MIN_PATH_GAIN:
				continue
			var row_bonus := _row_density_bonus(cell)
			var score := float(gain) * 100.0 + row_bonus - float(cell.y) * 0.05
			if score > best_score:
				best_score = score
				best_cell = cell
	if best_cell.x < 0:
		return false
	_fortify_tower_index += 1
	return lane.tower_manager.try_place_ai(WALL_TOWER, best_cell)


func _row_density_bonus(cell: Vector2i) -> float:
	var x_min := LaneCoords.buildable_x_min()
	var x_max := LaneCoords.buildable_x_max()
	var towers_on_row := 0
	for x in range(x_min, x_max + 1):
		if lane.build_grid.towers_by_cell.has(Vector2i(x, cell.y)):
			towers_on_row += 1
	var row_span := x_max - x_min + 1
	if towers_on_row > 0 and towers_on_row < row_span - 1:
		return 25.0
	return 0.0


func _get_path_cell_set() -> Dictionary:
	var cells: Dictionary = {}
	for wp in lane.path_manager.current_waypoints:
		cells[_cell_key(LaneCoords.world_to_grid(wp))] = true
	return cells


func _get_turn_cells() -> Array[Vector2i]:
	var grid_path: Array[Vector2i] = []
	for wp in lane.path_manager.current_waypoints:
		grid_path.append(LaneCoords.world_to_grid(wp))
	var turns: Array[Vector2i] = []
	for i in range(1, grid_path.size() - 1):
		var prev: Vector2i = grid_path[i - 1]
		var curr: Vector2i = grid_path[i]
		var next: Vector2i = grid_path[i + 1]
		var in_dir: Vector2i = Vector2i(signi(curr.x - prev.x), signi(curr.y - prev.y))
		var out_dir: Vector2i = Vector2i(signi(next.x - curr.x), signi(next.y - curr.y))
		if in_dir != out_dir:
			turns.append(curr)
	return turns


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
