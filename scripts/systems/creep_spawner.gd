class_name CreepSpawner
extends Node3D

## Spawns creeps and tracks active count.

signal creep_spawned(creep: Node)
signal creep_killed(creep: Node, gold: int)
signal creep_leaked(creep: Node, damage: int)
signal creep_redistributed(creep: Node, target_count: int)

const CREEP_SCENE := preload("res://scenes/entities/creep.tscn")

var path_manager: PathManager
var economy: EconomyManager
var tower_manager: TowerManager
var owner_lane: LaneController
var _active_creeps: Array = []
var kill_count: int = 0
var _next_net_id: int = 1
var _network_creeps: Dictionary = {}
var _client_mirror: bool = false


func setup(p_path: PathManager, p_economy: EconomyManager) -> void:
	path_manager = p_path
	economy = p_economy
	if not path_manager.path_updated.is_connected(_on_path_updated):
		path_manager.path_updated.connect(_on_path_updated)


func _on_path_updated(waypoints: Array) -> void:
	_active_creeps = _active_creeps.filter(func(c): return is_instance_valid(c))
	for creep in _active_creeps:
		if creep.has_method("repath"):
			creep.repath(waypoints.duplicate())


func set_client_mirror(enabled: bool) -> void:
	_client_mirror = enabled


func spawn_wave(wave_data: Dictionary) -> void:
	var creep_id: String = wave_data.get("creep", "grunt")
	var count: int = int(wave_data.get("count", 1))
	var interval: float = float(wave_data.get("interval", 0.5))
	for i in count:
		_spawn_creep(creep_id)
		if interval > 0.0 and i < count - 1:
			await get_tree().create_timer(interval).timeout
	for extra: Dictionary in wave_data.get("extras", []):
		var e_count: int = int(extra.get("count", 1))
		var e_interval: float = float(extra.get("interval", 0.5))
		for j in e_count:
			_spawn_creep(str(extra.get("creep", "grunt")))
			if e_interval > 0.0 and j < e_count - 1:
				await get_tree().create_timer(e_interval).timeout


func _spawn_creep(creep_id: String) -> void:
	var net_id := _next_net_id
	_next_net_id += 1
	var creep: Node3D = CREEP_SCENE.instantiate()
	add_child(creep)
	var waypoints := path_manager.current_waypoints.duplicate()
	if waypoints.is_empty():
		waypoints = path_manager.get_path_waypoints()
	creep.setup(creep_id, waypoints, self)
	if creep.has_method("set_network_state"):
		creep.set_network_state(net_id, _client_mirror)
	_network_creeps[net_id] = creep
	_active_creeps.append(creep)
	creep_spawned.emit(creep)
	_notify_creep_spawned(creep, net_id)


func spawn_network_creep(net_id: int, creep_id: String) -> void:
	if _network_creeps.has(net_id):
		return
	var creep: Node3D = CREEP_SCENE.instantiate()
	add_child(creep)
	var waypoints := path_manager.current_waypoints.duplicate()
	if waypoints.is_empty():
		waypoints = path_manager.get_path_waypoints()
	creep.setup(creep_id, waypoints, self)
	if creep.has_method("set_network_state"):
		creep.set_network_state(net_id, true)
	_network_creeps[net_id] = creep
	_active_creeps.append(creep)
	creep_spawned.emit(creep)


func despawn_network_creep(net_id: int) -> void:
	var creep = _network_creeps.get(net_id)
	if creep != null and is_instance_valid(creep):
		_active_creeps.erase(creep)
		creep.queue_free()
	_network_creeps.erase(net_id)


func pack_network_states() -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for creep in _active_creeps:
		if not is_instance_valid(creep):
			continue
		if not creep.has_method("get_network_state"):
			continue
		var state: PackedFloat32Array = creep.get_network_state()
		if state.size() >= 4:
			packed.append_array(state)
	return packed


func apply_network_states(packed: PackedFloat32Array) -> void:
	var i := 0
	while i + 3 < packed.size():
		var net_id := int(packed[i])
		var x := packed[i + 1]
		var z := packed[i + 2]
		var hp_norm := packed[i + 3]
		i += 4
		var creep = _network_creeps.get(net_id)
		if creep != null and is_instance_valid(creep) and creep.has_method("apply_network_state"):
			creep.apply_network_state(Vector3(x, creep.global_position.y, z), hp_norm)


func _notify_creep_spawned(creep: Node, net_id: int) -> void:
	if _client_mirror:
		return
	var match_node := get_tree().current_scene
	if match_node != null and match_node.has_method("notify_creep_spawned"):
		match_node.notify_creep_spawned(owner_lane, creep, net_id)


func _notify_creep_removed(net_id: int) -> void:
	if _client_mirror or net_id < 0:
		return
	var match_node := get_tree().current_scene
	if match_node != null and match_node.has_method("notify_creep_removed"):
		match_node.notify_creep_removed(owner_lane, net_id)


func on_creep_killed(creep: Node, bounty: int) -> void:
	_unregister_network_creep(creep)
	_active_creeps.erase(creep)
	kill_count += 1
	if economy:
		economy.add_gold(bounty, "kill")
	creep_killed.emit(creep, bounty)


func on_creep_leaked(creep: Node, damage: int) -> void:
	_unregister_network_creep(creep)
	creep_leaked.emit(creep, damage)


func _unregister_network_creep(creep: Node) -> void:
	if creep == null or not creep.has_method("get_network_id"):
		return
	var net_id: int = creep.get_network_id()
	if net_id >= 0:
		_network_creeps.erase(net_id)
		_notify_creep_removed(net_id)


func redistribute_creep(creep: Node) -> void:
	_active_creeps.erase(creep)
	var match_node := get_tree().current_scene
	if match_node == null or not match_node.has_method("get_redistribution_targets"):
		creep.queue_free()
		return
	var targets: Array = match_node.get_redistribution_targets(owner_lane)
	if targets.is_empty():
		creep.queue_free()
		return
	var health_splits := _split_health(float(creep.current_health), targets.size())
	var armor := str(creep.armor_type) if "armor_type" in creep else "light"
	for i in targets.size():
		var target_lane = targets[i]
		if target_lane is LaneController:
			target_lane.creep_spawner.spawn_transferred_creep(
				str(creep.creep_id),
				health_splits[i],
				armor
			)
	creep_redistributed.emit(creep, targets.size())
	creep.queue_free()


func _split_health(total: float, count: int) -> Array:
	var splits: Array = []
	if count <= 0 or total <= 0.0:
		return splits
	var each := total / float(count)
	var assigned := 0.0
	for i in count:
		var amount := each
		if i == count - 1:
			amount = total - assigned
		else:
			assigned += amount
		splits.append(maxf(amount, 1.0))
	return splits


func spawn_transferred_creep(creep_id: String, health: float, armor_type: String) -> void:
	if health <= 0.0:
		return
	var creep: Node3D = CREEP_SCENE.instantiate()
	add_child(creep)
	var waypoints := path_manager.current_waypoints.duplicate()
	if waypoints.is_empty():
		waypoints = path_manager.get_path_waypoints()
	creep.setup(creep_id, waypoints, self)
	if creep.has_method("transfer_health"):
		creep.transfer_health(health, armor_type)
	_active_creeps.append(creep)
	creep_spawned.emit(creep)


func spawn_test_creep(creep_id: String) -> void:
	_spawn_creep(creep_id)


func active_creep_count() -> int:
	_active_creeps = _active_creeps.filter(func(c): return is_instance_valid(c))
	return _active_creeps.size()


func get_active_creeps() -> Array:
	_active_creeps = _active_creeps.filter(func(c): return is_instance_valid(c))
	return _active_creeps
