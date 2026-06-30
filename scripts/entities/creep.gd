extends CharacterBody3D

## Creep runs spawn → core, leaks damage, then respawns at spawn with leftover HP.

signal died
signal reached_core

const WAYPOINT_ARRIVE_DIST := 0.35
const ENDPOINT_ARRIVE_DIST_RATIO := 0.55

var creep_id: String = ""
var max_health: float = 100.0
var current_health: float = 100.0
var armor_type: String = "light"
var move_speed: float = 3.5
var core_damage: int = 1
var gold_bounty: int = 4
var slow_multiplier: float = 1.0
var _slow_timer: float = 0.0

var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _spawner: CreepSpawner
var _health_bar: Node3D
var _core_hit_handled: bool = false
var network_id: int = -1
var network_drive: bool = false
var _net_target_pos: Vector3 = Vector3.ZERO
var _net_has_target: bool = false

const NET_SNAP_DIST_SQ := 9.0
const NET_LERP_SPEED := 14.0


func set_network_state(net_id: int, drive: bool) -> void:
	network_id = net_id
	network_drive = drive


func get_network_id() -> int:
	return network_id


func get_network_state() -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	packed.append(float(network_id))
	packed.append(global_position.x)
	packed.append(global_position.z)
	var hp_norm := current_health / maxf(max_health, 1.0)
	packed.append(hp_norm)
	return packed


func apply_network_state(pos: Vector3, hp_norm: float) -> void:
	_net_target_pos = pos
	_net_target_pos.y = global_position.y
	if not _net_has_target:
		global_position = _net_target_pos
	_net_has_target = true
	current_health = max_health * clampf(hp_norm, 0.0, 1.0)
	if _health_bar != null and _health_bar.has_method("update_health"):
		_health_bar.update_health(current_health, max_health)


func setup(p_creep_id: String, waypoints: Array, spawner: CreepSpawner) -> void:
	creep_id = p_creep_id
	_spawner = spawner
	_set_waypoints(waypoints)
	_apply_definition()
	_build_visual()
	_setup_health_bar()
	_respawn_at_spawn(false)


func _apply_definition() -> void:
	var def: Dictionary = BalanceConfig.get_creep_def(creep_id)
	max_health = float(def.get("health", 80))
	current_health = max_health
	armor_type = str(def.get("armor_type", "light"))
	move_speed = LaneCoords.tile_speed_to_world(float(def.get("speed", 1.75)))
	core_damage = int(def.get("core_damage", 1))
	gold_bounty = int(def.get("gold_bounty", 4))


func _build_visual() -> void:
	var def: Dictionary = BalanceConfig.get_creep_def(creep_id)
	var mesh_inst := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35 * float(def.get("scale", 1.0))
	mesh.height = 0.9 * float(def.get("scale", 1.0))
	mesh_inst.mesh = mesh
	mesh_inst.position.y = mesh.height * 0.5
	var mat := StandardMaterial3D.new()
	var c: Array = def.get("color", [0.5, 0.5, 0.5])
	mat.albedo_color = Color(c[0], c[1], c[2])
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _setup_health_bar() -> void:
	var bar_scene := preload("res://scenes/ui/health_bar.tscn")
	_health_bar = bar_scene.instantiate()
	add_child(_health_bar)
	if _health_bar.has_method("setup"):
		_health_bar.setup(self)


func _physics_process(delta: float) -> void:
	if network_drive:
		if _net_has_target:
			if global_position.distance_squared_to(_net_target_pos) > NET_SNAP_DIST_SQ:
				global_position = _net_target_pos
			else:
				global_position = global_position.lerp(
					_net_target_pos,
					minf(1.0, delta * NET_LERP_SPEED)
				)
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			slow_multiplier = 1.0
	if _at_core():
		_hit_core()
		return
	_follow_waypoints()


func _follow_waypoints() -> void:
	if _waypoint_index >= _waypoints.size():
		_hit_core()
		return
	var target := _waypoints[_waypoint_index]
	var to_target := target - position
	to_target.y = 0.0
	if to_target.length() < WAYPOINT_ARRIVE_DIST:
		_waypoint_index += 1
		return
	velocity = to_target.normalized() * move_speed * slow_multiplier
	move_and_slide()


func _set_waypoints(waypoints: Array) -> void:
	_waypoints.clear()
	for wp in waypoints:
		_waypoints.append(wp)


func repath(new_waypoints: Array) -> void:
	if new_waypoints.is_empty():
		return
	var progress := _progress_along_path(_waypoints, position)
	_set_waypoints(new_waypoints)
	_waypoint_index = _index_for_progress(_waypoints, progress)
	_resolve_blocked_position()
	_skip_waypoints_already_at()


func _progress_along_path(waypoints: Array, pos: Vector3) -> float:
	if waypoints.is_empty():
		return 0.0
	var best_dist_sq := INF
	var best_progress := 0.0
	var traveled := 0.0
	for i in range(1, waypoints.size()):
		var a := Vector2(waypoints[i - 1].x, waypoints[i - 1].z)
		var b := Vector2(waypoints[i].x, waypoints[i].z)
		var p := Vector2(pos.x, pos.z)
		var ab := b - a
		var seg_len := ab.length()
		if seg_len < 0.001:
			continue
		var t := clampf((p - a).dot(ab) / (seg_len * seg_len), 0.0, 1.0)
		var closest := a + ab * t
		var d_sq := p.distance_squared_to(closest)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_progress = traveled + seg_len * t
		traveled += seg_len
	return best_progress


func _index_for_progress(waypoints: Array, progress: float) -> int:
	if waypoints.is_empty():
		return 0
	var traveled := 0.0
	for i in range(1, waypoints.size()):
		var seg := Vector2(
			waypoints[i].x - waypoints[i - 1].x,
			waypoints[i].z - waypoints[i - 1].z
		).length()
		if traveled + seg >= progress - 0.01:
			return i
		traveled += seg
	return waypoints.size() - 1


func _resolve_blocked_position() -> void:
	if not _is_on_blocked_cell():
		return
	for i in range(_waypoint_index, _waypoints.size()):
		var cell := LaneCoords.world_to_grid(_waypoints[i])
		if not _is_cell_blocked(cell):
			_waypoint_index = i
			position = _waypoints[i]
			return
	var best_i := _waypoint_index
	var best_d := INF
	for i in _waypoints.size():
		var cell := LaneCoords.world_to_grid(_waypoints[i])
		if _is_cell_blocked(cell):
			continue
		var d := position.distance_squared_to(_waypoints[i])
		if d < best_d:
			best_d = d
			best_i = i
	_waypoint_index = best_i
	position = _waypoints[best_i]


func _is_on_blocked_cell() -> bool:
	return _is_cell_blocked(LaneCoords.world_to_grid(position))


func _is_cell_blocked(cell: Vector2i) -> bool:
	if _spawner == null or _spawner.path_manager == null or _spawner.path_manager.lane_grid == null:
		return false
	return _spawner.path_manager.lane_grid.is_occupied(cell)


func _refresh_path_from_lane() -> void:
	if _spawner == null or _spawner.path_manager == null:
		return
	var fresh := _spawner.path_manager.current_waypoints
	if fresh.is_empty():
		fresh = _spawner.path_manager.get_path_waypoints()
	_set_waypoints(fresh)


func _respawn_at_spawn(refresh_path: bool = true) -> void:
	_core_hit_handled = false
	velocity = Vector3.ZERO
	slow_multiplier = 1.0
	_slow_timer = 0.0
	if refresh_path:
		_refresh_path_from_lane()
	_waypoint_index = 0
	if _waypoints.size() > 0:
		position = _waypoints[0]
	_skip_waypoints_already_at()
	if _health_bar and _health_bar.has_method("update_health"):
		_health_bar.update_health(current_health, max_health)


func _skip_waypoints_already_at() -> void:
	while _waypoint_index < _waypoints.size():
		var target := _waypoints[_waypoint_index]
		var flat := Vector2(position.x - target.x, position.z - target.z)
		if flat.length() >= WAYPOINT_ARRIVE_DIST:
			break
		_waypoint_index += 1


func _endpoint_arrive_dist() -> float:
	return LaneCoords.cell_size * ENDPOINT_ARRIVE_DIST_RATIO


func _at_core() -> bool:
	if _waypoints.is_empty():
		return false
	var core := _waypoints[_waypoints.size() - 1]
	var flat := Vector2(position.x - core.x, position.z - core.z)
	return flat.length() <= _endpoint_arrive_dist()


func take_damage(amount: float, damage_type: String, source_tower_id: String = "") -> void:
	if network_drive:
		return
	var rolled_damage := BalanceConfig.roll_damage(amount)
	var mult := BalanceConfig.get_damage_multiplier(damage_type, armor_type)
	var final_damage := rolled_damage * mult
	var is_high_roll := rolled_damage > amount * 1.05
	var is_low_roll := rolled_damage < amount * 0.95
	current_health -= final_damage
	var is_bonus := mult > 1.05 or is_high_roll
	var is_reduced := (mult < 0.95 or is_low_roll) and not is_bonus
	DamageNumbers.spawn(
		global_position + Vector3(0, 1.2, 0),
		final_damage,
		is_bonus,
		is_reduced
	)
	if _health_bar and _health_bar.has_method("update_health"):
		_health_bar.update_health(current_health, max_health)
	if source_tower_id != "" and _spawner and _spawner.tower_manager:
		_spawner.tower_manager.record_damage(source_tower_id, final_damage)
	if current_health <= 0.0:
		_die()


func apply_slow(percent: float, duration: float) -> void:
	slow_multiplier = 1.0 - percent
	_slow_timer = duration


func _die() -> void:
	if _spawner:
		_spawner.on_creep_killed(self, gold_bounty)
	died.emit()
	queue_free()


func _hit_core() -> void:
	if _core_hit_handled:
		return
	_core_hit_handled = true
	if _spawner and _spawner.owner_lane and _spawner.owner_lane.is_eliminated:
		_spawner.redistribute_creep(self)
		reached_core.emit()
		return
	if _spawner:
		_spawner.on_creep_leaked(self, core_damage)
	reached_core.emit()
	_respawn_at_spawn()


func transfer_health(health: float, p_armor_type: String = "") -> void:
	current_health = clampf(health, 0.0, max_health)
	if p_armor_type != "":
		armor_type = p_armor_type
	if _health_bar and _health_bar.has_method("update_health"):
		_health_bar.update_health(current_health, max_health)
	_respawn_at_spawn(false)
