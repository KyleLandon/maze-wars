class_name MatchNetwork
extends Node

## Host-authoritative multiplayer sync for 2-player matches.

const SYNC_INTERVAL := 0.12

var _match: Node3D
var _lanes_by_id: Dictionary = {}
var _lanes_by_peer: Dictionary = {}
var _sync_timer: float = 0.0
var _client_mirror: bool = false


static func _dict_from_variant(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _json_to_dict(json_text: String) -> Dictionary:
	if json_text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(json_text)
	return parsed if parsed is Dictionary else {}


static func _dict_to_json(data: Dictionary) -> String:
	return JSON.stringify(data)


static func _pack_selected_cells(lane) -> PackedInt32Array:
	var packed := PackedInt32Array()
	if lane == null:
		return packed
	for tower in lane.tower_manager.selected_towers:
		if is_instance_valid(tower):
			packed.append(tower.grid_cell.x)
			packed.append(tower.grid_cell.y)
	return packed


static func _apply_selection_from_cells(lane, cells: PackedInt32Array) -> void:
	if lane == null:
		return
	var tm = lane.tower_manager
	var picked: Array = []
	var i := 0
	while i + 1 < cells.size():
		var cell := Vector2i(cells[i], cells[i + 1])
		var tower = tm.build_grid.get_tower_at(cell)
		if tower != null:
			picked.append(tower)
		i += 2
	tm.select_towers_at_cells(picked)


func setup(match_root: Node3D, lanes: Array) -> void:
	_match = match_root
	_lanes_by_id.clear()
	_lanes_by_peer.clear()
	for lane in lanes:
		if lane == null:
			continue
		_lanes_by_id[lane.lane_id] = lane
		_lanes_by_peer[lane.control_peer_id] = lane
	_client_mirror = NetworkManager.is_online() and not multiplayer.is_server()
	if _client_mirror:
		_disable_client_simulation(lanes)
	if multiplayer.is_server():
		set_process(true)
		_sync_initial_state()
	else:
		set_process(false)


func _sync_initial_state() -> void:
	for lane in _lanes_by_id.values():
		if lane == null:
			continue
		_broadcast_lane_economy(lane)
		on_core_health_changed(lane)


func lane_for_peer(peer_id: int):
	return _lanes_by_peer.get(peer_id)


func lane_by_id(lane_id: String):
	return _lanes_by_id.get(lane_id)


func request_place_tower(cell: Vector2i, tower_id: String) -> void:
	if not NetworkManager.is_online():
		_apply_place(_match.local_lane, cell, tower_id, true)
		return
	if multiplayer.is_server():
		_apply_place(_match.local_lane, cell, tower_id, true)
	else:
		_server_place_tower.rpc_id(1, cell.x, cell.y, tower_id)


func request_upgrade() -> void:
	var cells := _pack_selected_cells(_match.local_lane)
	if not NetworkManager.is_online():
		_match.local_lane.tower_manager.try_upgrade()
		return
	if multiplayer.is_server():
		_apply_upgrade_for_peer(multiplayer.get_unique_id(), cells)
	else:
		_server_upgrade.rpc_id(1, cells)


func request_sell() -> void:
	var cells := _pack_selected_cells(_match.local_lane)
	if not NetworkManager.is_online():
		_match.local_lane.tower_manager.try_sell()
		return
	if multiplayer.is_server():
		_apply_sell_for_peer(multiplayer.get_unique_id(), cells)
	else:
		_server_sell.rpc_id(1, cells)


func request_send(package_id: String) -> void:
	if not NetworkManager.is_online():
		_match._execute_send(package_id)
		return
	if multiplayer.is_server():
		_apply_send_for_peer(multiplayer.get_unique_id(), package_id)
	else:
		_server_send.rpc_id(1, package_id)


func request_build_mode(tower_id: String) -> void:
	_match.local_lane.tower_manager.set_build_mode(tower_id)


func request_cancel_build_mode() -> void:
	_match.local_lane.tower_manager.cancel_build_mode()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_sync_timer -= delta
	if _sync_timer > 0.0:
		return
	_sync_timer = SYNC_INTERVAL
	_broadcast_creep_states()


func _disable_client_simulation(lanes: Array) -> void:
	if _match.wave_coordinator:
		_match.wave_coordinator.set_process(false)
	for lane in lanes:
		if lane == null:
			continue
		lane.economy.set_process(false)
		lane.creep_spawner.set_client_mirror(true)


@rpc("any_peer", "call_remote", "reliable")
func _server_place_tower(cx: int, cy: int, tower_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_apply_place(lane_for_peer(peer_id), Vector2i(cx, cy), tower_id, true)


@rpc("any_peer", "call_remote", "reliable")
func _server_upgrade(cells: PackedInt32Array) -> void:
	if not multiplayer.is_server():
		return
	_apply_upgrade_for_peer(multiplayer.get_remote_sender_id(), cells)


@rpc("any_peer", "call_remote", "reliable")
func _server_sell(cells: PackedInt32Array) -> void:
	if not multiplayer.is_server():
		return
	_apply_sell_for_peer(multiplayer.get_remote_sender_id(), cells)


@rpc("any_peer", "call_remote", "reliable")
func _server_send(package_id: String) -> void:
	if not multiplayer.is_server():
		return
	_apply_send_for_peer(multiplayer.get_remote_sender_id(), package_id)


func _apply_place(lane, cell: Vector2i, tower_id: String, broadcast: bool) -> void:
	if lane == null:
		return
	var tm = lane.tower_manager
	var previous_mode: String = tm.build_mode_tower_id
	if tower_id != "" and previous_mode != tower_id:
		tm.set_build_mode(tower_id)
	var result: Dictionary = tm.try_place(cell)
	if multiplayer.is_server() and lane.control_peer_id != multiplayer.get_unique_id():
		rpc_placement_result.rpc_id(
			lane.control_peer_id,
			result.get("success", false),
			str(result.get("reason", ""))
		)
	if result.get("success", false) and broadcast:
		rpc_sync_tower_placed.rpc(lane.lane_id, tower_id, cell.x, cell.y)


func _apply_upgrade_for_peer(peer_id: int, cells: PackedInt32Array) -> void:
	var lane = lane_for_peer(peer_id)
	if lane == null:
		return
	_apply_selection_from_cells(lane, cells)
	var before: Array = lane.tower_manager.selected_towers.duplicate()
	var result: Dictionary = lane.tower_manager.try_upgrade()
	_notify_peer_action(peer_id, result, true)
	_broadcast_lane_economy(lane)
	for tower in before:
		if is_instance_valid(tower) and tower.has_method("get_undo_snapshot"):
			var snapshot: Dictionary = tower.get_undo_snapshot()
			var cell: Vector2i = lane.tower_manager._grid_cell_from_state(snapshot.get("grid_cell", Vector2i.ZERO))
			rpc_sync_tower_state.rpc(
				lane.lane_id,
				cell.x,
				cell.y,
				_dict_to_json(snapshot)
			)


func _apply_sell_for_peer(peer_id: int, cells: PackedInt32Array) -> void:
	var lane = lane_for_peer(peer_id)
	if lane == null:
		return
	_apply_selection_from_cells(lane, cells)
	var result: Dictionary = lane.tower_manager.try_sell()
	_notify_peer_action(peer_id, result, true)
	_broadcast_lane_economy(lane)
	for cell_value in result.get("sold_cells", []):
		var cell: Vector2i = lane.tower_manager._grid_cell_from_state(cell_value)
		rpc_sync_tower_sold.rpc(lane.lane_id, cell.x, cell.y)


func _apply_send_for_peer(peer_id: int, package_id: String) -> void:
	var lane = lane_for_peer(peer_id)
	if lane == null:
		return
	var targets: Array = []
	for other in _lanes_by_id.values():
		if other != lane and not other.is_eliminated:
			targets.append(other)
	var result: Dictionary = _match.send_manager.purchase_for_lane(lane, targets, package_id)
	_notify_peer_action(peer_id, result, false, true)
	_broadcast_lane_economy(lane)
	if result.get("success", false):
		var pkg: Dictionary = _dict_from_variant(result.get("package", {}))
		for target in targets:
			if target.is_eliminated:
				continue
			rpc_sync_send_package.rpc(target.lane_id, _dict_to_json(pkg))


func on_wave_started(wave_number: int, wave_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	rpc_sync_wave_started.rpc(wave_number, _dict_to_json(wave_data))


func on_wave_preview(wave_number: int, wave_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	rpc_sync_wave_preview.rpc(wave_number, _dict_to_json(wave_data))


func on_economy_changed(lane) -> void:
	if not multiplayer.is_server() or lane == null:
		return
	_broadcast_lane_economy(lane)


func on_core_health_changed(lane) -> void:
	if not multiplayer.is_server() or lane == null:
		return
	rpc_sync_core_health.rpc(
		lane.lane_id,
		lane.core.current_health,
		lane.core.max_health
	)


func on_creep_spawned(lane, creep: Node, net_id: int) -> void:
	if not multiplayer.is_server() or lane == null or creep == null:
		return
	rpc_spawn_network_creep.rpc(lane.lane_id, net_id, creep.creep_id)


func on_creep_removed(lane, net_id: int) -> void:
	if not multiplayer.is_server() or lane == null:
		return
	rpc_despawn_network_creep.rpc(lane.lane_id, net_id)


func on_match_end(winner_peer_id: int, stats: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	rpc_sync_match_end.rpc(winner_peer_id, _dict_to_json(stats))


func _notify_peer_action(peer_id: int, result: Dictionary, refresh_towers: bool, show_local: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var success: bool = result.get("success", false)
	var message := str(result.get("reason", ""))
	if peer_id == multiplayer.get_unique_id():
		if show_local:
			var color := BrandColors.UI_SUCCESS if success else BrandColors.UI_DANGER
			_match.hud.show_message(message, color)
		if refresh_towers:
			_match._refresh_local_tower_ui()
		return
	rpc_action_feedback.rpc_id(peer_id, success, message, refresh_towers)


func _broadcast_lane_economy(lane) -> void:
	rpc_sync_economy.rpc(lane.lane_id, lane.economy.gold, lane.economy.income)


func _broadcast_creep_states() -> void:
	for lane in _lanes_by_id.values():
		if lane == null:
			continue
		var packed: PackedFloat32Array = lane.creep_spawner.pack_network_states()
		if packed.is_empty():
			continue
		rpc_sync_creep_states.rpc(lane.lane_id, packed)


@rpc("authority", "call_remote", "reliable")
func rpc_action_feedback(success: bool, message: String, refresh_towers: bool) -> void:
	if multiplayer.is_server():
		return
	var color := BrandColors.UI_SUCCESS if success else BrandColors.UI_DANGER
	_match.hud.show_message(message, color)
	_match.hud.update_economy(_match.local_lane.economy.gold, _match.local_lane.economy.income)
	if refresh_towers:
		_match._refresh_local_tower_ui()


@rpc("authority", "call_remote", "reliable")
func rpc_placement_result(success: bool, message: String) -> void:
	if multiplayer.is_server():
		return
	_match._on_placement_result(success, message)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_tower_placed(lane_id: String, tower_id: String, cx: int, cy: int) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.tower_manager.apply_remote_place(tower_id, Vector2i(cx, cy))


@rpc("authority", "call_remote", "reliable")
func rpc_sync_tower_state(lane_id: String, cx: int, cy: int, info_json: String) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.tower_manager.apply_remote_tower_state(Vector2i(cx, cy), _json_to_dict(info_json))


@rpc("authority", "call_remote", "reliable")
func rpc_sync_tower_sold(lane_id: String, cx: int, cy: int) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.tower_manager.apply_remote_sell(Vector2i(cx, cy))


@rpc("authority", "call_remote", "reliable")
func rpc_sync_economy(lane_id: String, gold: int, income: int) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.economy.apply_network_state(gold, income)
		if lane.is_local_lane():
			_match.hud.update_economy(gold, income)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_core_health(lane_id: String, current: int, max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.core.apply_network_health(current, max_hp)
		if lane.is_local_lane():
			_match.hud.update_core_health(current, max_hp)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_wave_preview(wave_number: int, wave_data_json: String) -> void:
	if multiplayer.is_server():
		return
	_match._on_wave_preview(wave_number, _json_to_dict(wave_data_json))


@rpc("authority", "call_remote", "reliable")
func rpc_sync_wave_started(wave_number: int, wave_data_json: String) -> void:
	if multiplayer.is_server():
		return
	var wave_data := _json_to_dict(wave_data_json)
	_match._on_wave_started(wave_number, wave_data)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_send_package(lane_id: String, pkg_json: String) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.spawn_send_package(_json_to_dict(pkg_json))


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_network_creep(lane_id: String, net_id: int, creep_id: String) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.creep_spawner.spawn_network_creep(net_id, creep_id)


@rpc("authority", "call_remote", "unreliable")
func rpc_sync_creep_states(lane_id: String, packed: PackedFloat32Array) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.creep_spawner.apply_network_states(packed)


@rpc("authority", "call_remote", "reliable")
func rpc_despawn_network_creep(lane_id: String, net_id: int) -> void:
	if multiplayer.is_server():
		return
	var lane = lane_by_id(lane_id)
	if lane:
		lane.creep_spawner.despawn_network_creep(net_id)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_match_end(winner_peer_id: int, stats_json: String) -> void:
	if multiplayer.is_server():
		return
	var victory := winner_peer_id == 0 or winner_peer_id == multiplayer.get_unique_id()
	_match._show_match_end(victory, _json_to_dict(stats_json))
