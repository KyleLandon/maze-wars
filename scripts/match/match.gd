extends Node3D

## Main match controller — player lane + AI opponent lanes.

const LaneControllerScript := preload("res://scripts/systems/lane_controller.gd")
const MatchWaveCoordinatorScript := preload("res://scripts/systems/match_wave_coordinator.gd")

@onready var camera: Camera3D = $CameraRig
@onready var hud: Control = $UI/HUD
@onready var post_match: Control = $UI/PostMatch
@onready var debug_panel: PanelContainer = $UI/DebugPanel
@onready var scoreboard: Control = $UI/Scoreboard
@onready var pause_menu: Control = $UI/PauseMenu
@onready var lanes_root: Node3D = $Lanes
@onready var send_manager: SendManager = $SendManager
@onready var network: MatchNetwork = $MatchNetwork

var local_lane: LaneController
var opponent_lane: LaneController
var human_lanes: Array = []
var ai_lanes: Array = []
var wave_coordinator: MatchWaveCoordinator
var builder: CharacterBody3D
var _match_over: bool = false
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _select_dragging: bool = false
var _select_drag_start: Vector2 = Vector2.ZERO
var _pending_place_cell: Vector2i = Vector2i(-1, -1)
const SELECT_DRAG_THRESHOLD := 8.0


func _ready() -> void:
	LaneCoords.load_from_config()
	_spawn_lanes()
	if NetworkManager.is_online() and not NetworkManager.is_dedicated_server and local_lane == null:
		push_error("No lane for peer %d — lobby peer map missing." % NetworkManager.get_local_peer_id())
		NetworkManager.leave_lobby()
		return
	_setup_wave_coordinator()
	network.set_multiplayer_authority(1)
	var all_lanes: Array = human_lanes.duplicate()
	all_lanes.append_array(ai_lanes)
	network.setup(self, all_lanes)
	_refresh_lane_display_names()
	_spawn_builder()
	_setup_send_manager()
	_setup_ai_brains()
	_connect_signals()
	GameConfig.match_active = true
	GameConfig.match_start_time = Time.get_ticks_msec() / 1000.0
	if NetworkManager.is_online():
		NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	if NetworkManager.is_dedicated_server:
		$UI.visible = false


func _exit_tree() -> void:
	NetworkManager.unregister_match_network()


func _spawn_lanes() -> void:
	var spacing := float(BalanceConfig.economy.get("lane_spacing", 6.0))
	var stride := LaneCoords.lane_stride(spacing)
	human_lanes.clear()
	ai_lanes.clear()

	if NetworkManager.is_online():
		var player_count := NetworkManager.match_player_count
		var peer_ids := _collect_lobby_peer_ids()
		for i in range(player_count):
			var lane_id := "player" if i == 0 else "player_%d" % (i + 1)
			var offset := _online_lane_offset(i, stride)
			var peer_id := int(peer_ids[i]) if i < peer_ids.size() else 0
			var lane: LaneController = _create_lane(
				"PlayerLane%d" % (i + 1),
				offset,
				lane_id,
				_lane_label_for_index(i),
				true,
				peer_id
			)
			human_lanes.append(lane)
		for lane in human_lanes:
			if lane.is_local_lane():
				local_lane = lane
				break
		if local_lane == null and NetworkManager.is_dedicated_server and not human_lanes.is_empty():
			local_lane = human_lanes[0]
		opponent_lane = null
	else:
		local_lane = _create_lane("PlayerLane", Vector3.ZERO, "player", "Your Lane", true, 1)
		human_lanes = [local_lane]
		opponent_lane = null
		var ai_count: int = int(BalanceConfig.economy.get("ai_lane_count", 2))
		var ai_names := ["AI North", "AI South", "AI East"]
		var slot := 0
		for i in ai_count:
			var ai_lane: LaneController = _create_lane(
				"AILane%d" % ((slot >> 1) + 1),
				Vector3((1 if slot % 2 == 0 else -1) * ((slot >> 1) + 1) * stride, 0.0, 0.0),
				"ai_%d" % ((slot >> 1) + 1),
				ai_names[slot % ai_names.size()],
				false,
				0
			)
			ai_lanes.append(ai_lane)
			slot += 1

	if local_lane != null and camera.has_method("set_lane_center"):
		camera.set_lane_center(local_lane.global_position)


func _collect_lobby_peer_ids() -> Array:
	var peer_ids: Array = []
	for slot in NetworkManager.get_lobby_slots():
		if slot.is_empty():
			continue
		var peer_id := int(slot.get("peer_id", 0))
		if peer_id > 0:
			peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids


func _create_lane(
	node_name: String,
	position: Vector3,
	lane_id: String,
	display_name: String,
	is_player_lane: bool,
	peer_id: int
) -> LaneController:
	var lane: LaneController = LaneControllerScript.new()
	lane.name = node_name
	lanes_root.add_child(lane)
	lane.position = position
	lane.setup(lane_id, display_name, is_player_lane, peer_id)
	return lane


func _online_lane_offset(index: int, stride: float) -> Vector3:
	if index <= 0:
		return Vector3.ZERO
	var slot := index - 1
	var x := (1 if slot % 2 == 0 else -1) * ((slot >> 1) + 1) * stride
	return Vector3(x, 0.0, 0.0)


func _lane_label_for_index(index: int) -> String:
	return "Player %d" % (index + 1)


func _refresh_lane_display_names() -> void:
	for lane in human_lanes:
		if lane is LaneController and lane.is_local_lane():
			lane.display_name = "Your Lane"


func _setup_wave_coordinator() -> void:
	wave_coordinator = MatchWaveCoordinatorScript.new()
	wave_coordinator.name = "WaveCoordinator"
	add_child(wave_coordinator)
	var all_lanes: Array = human_lanes.duplicate()
	all_lanes.append_array(ai_lanes)
	wave_coordinator.setup(all_lanes)


func _spawn_builder() -> void:
	if NetworkManager.is_dedicated_server or local_lane == null:
		return
	var builder_scene: PackedScene = preload("res://scenes/entities/builder.tscn")
	builder = builder_scene.instantiate()
	local_lane._entities.add_child(builder)
	builder.position = LaneCoords.grid_to_world_center(LaneCoords.builder_cell)
	builder.position.y = 0.5


func _setup_send_manager() -> void:
	if local_lane == null:
		return
	var enemy_lanes: Array = ai_lanes.duplicate()
	for lane in human_lanes:
		if lane != local_lane:
			enemy_lanes.append(lane)
	send_manager.setup(local_lane, enemy_lanes, local_lane.economy, wave_coordinator)


func _setup_ai_brains() -> void:
	for ai_lane in ai_lanes:
		var enemies := _enemy_lanes_for(ai_lane)
		ai_lane.ai_brain.configure_sending(send_manager, wave_coordinator, enemies)


func _enemy_lanes_for(ai_lane: LaneController) -> Array:
	var enemies: Array = human_lanes.duplicate()
	for other in ai_lanes:
		if other != ai_lane:
			enemies.append(other)
	return enemies.filter(func(l): return l != ai_lane)


func get_redistribution_targets(from_lane: LaneController) -> Array:
	var targets: Array = []
	for lane in human_lanes:
		if lane is LaneController and lane != from_lane and not lane.is_eliminated:
			targets.append(lane)
	for lane in ai_lanes:
		if lane is LaneController and lane != from_lane and not lane.is_eliminated:
			targets.append(lane)
	return targets


func _connect_signals() -> void:
	if local_lane == null:
		return
	var economy := local_lane.economy
	var tower_manager := local_lane.tower_manager
	var creep_spawner := local_lane.creep_spawner
	var core := local_lane.core

	economy.gold_changed.connect(func(g): hud.update_economy(g, economy.income))
	economy.income_changed.connect(func(i): hud.update_economy(economy.gold, i))
	economy.income_tick.connect(hud.update_income_timer)
	send_manager.send_timer.connect(hud.update_send_timer)
	send_manager.send_released.connect(_on_send_released)
	wave_coordinator.wave_started.connect(_on_wave_started)
	wave_coordinator.wave_preview.connect(_on_wave_preview)
	wave_coordinator.all_waves_complete.connect(_on_all_waves_complete)
	core.health_changed.connect(hud.update_core_health)
	core.destroyed.connect(_on_local_lane_defeat)
	local_lane.creep_leaked.connect(_on_player_leak)
	tower_manager.towers_selection_changed.connect(_on_towers_selection_changed)
	tower_manager.tower_deselected.connect(func(): hud.hide_tower_info())
	tower_manager.placement_result.connect(_on_placement_result)
	tower_manager.build_mode_changed.connect(_on_build_mode_changed)
	hud.tower_build_requested.connect(func(tower_id: String): tower_manager.set_build_mode(tower_id))
	hud.upgrade_requested.connect(func(): network.request_upgrade())
	hud.sell_requested.connect(func(): network.request_sell())
	hud.undo_requested.connect(_on_undo_requested)
	hud.send_requested.connect(_on_send_requested)
	post_match.dismissed.connect(_restart_match)
	pause_menu.forfeit_requested.connect(_on_forfeit_requested)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	debug_panel.add_gold_requested.connect(func(a): economy.add_gold(a, "debug"))
	debug_panel.add_income_requested.connect(func(a): economy.add_income(a))
	debug_panel.force_wave_requested.connect(wave_coordinator.force_start_wave)
	debug_panel.force_send_requested.connect(func(): pass)
	debug_panel.spawn_creep_requested.connect(creep_spawner.spawn_test_creep)

	for lane in human_lanes + ai_lanes:
		if lane == local_lane:
			continue
		if lane is LaneController and lane.is_player and not lane.is_local_lane():
			lane.core.destroyed.connect(_on_opponent_defeat)
		if lane is LaneController and lane.ai_brain:
			lane.core_destroyed.connect(_on_ai_lane_destroyed)
			lane.ai_brain.send_executed.connect(func(pkg_name, hit_player): _on_ai_send_executed(lane, pkg_name, hit_player))
		if lane is LaneController:
			lane.creep_spawner.creep_redistributed.connect(
				func(_creep, target_count): _on_creeps_redistributed(lane, target_count)
			)
			_connect_lane_network_signals(lane)

	_connect_lane_network_signals(local_lane)

	hud.update_economy(economy.gold, economy.income)
	hud.update_core_health(core.current_health, core.max_health)
	hud.update_send_timer(-1.0)
	if NetworkManager.is_online():
		var count := NetworkManager.match_player_count
		if count > 2:
			hud.show_message("%d-player FFA — sends hit all enemy lanes" % count, BrandColors.UI_ACCENT)
		else:
			hud.show_message("2-player match — sends hit your opponent", BrandColors.UI_ACCENT)


func _connect_lane_network_signals(lane: LaneController) -> void:
	if not NetworkManager.is_online():
		return
	lane.economy.gold_changed.connect(func(_g: int) -> void:
		if NetworkManager.is_server():
			network.on_economy_changed(lane)
	)
	lane.core.health_changed.connect(func(_c: int, _m: int) -> void:
		if NetworkManager.is_server():
			network.on_core_health_changed(lane)
	)


func _input(event: InputEvent) -> void:
	if NetworkManager.is_dedicated_server:
		return
	if _match_over:
		return
	if event.is_action("show_scoreboard"):
		if event.is_pressed():
			get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _match_over or not scoreboard:
		if scoreboard and scoreboard.visible:
			scoreboard.hide_board()
		return
	if Input.is_action_pressed("show_scoreboard"):
		scoreboard.show_board(get_scoreboard_rows())
	else:
		scoreboard.hide_board()


func get_scoreboard_rows() -> Array:
	var rows: Array = []
	for lane in human_lanes:
		if lane is LaneController:
			rows.append(lane.get_scoreboard_stats())
	for lane in ai_lanes:
		if lane is LaneController:
			rows.append(lane.get_scoreboard_stats())
	return rows


func _unhandled_input(event: InputEvent) -> void:
	if NetworkManager.is_dedicated_server:
		return
	if _match_over:
		return
	if event.is_action_pressed("ui_cancel"):
		_handle_escape()
		return
	if event.is_action_pressed("toggle_debug"):
		debug_panel.visible = not debug_panel.visible
	if event is InputEventMouseMotion:
		if _select_dragging:
			_update_select_drag()
		else:
			_update_hover()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if local_lane.tower_manager.build_mode_tower_id != "":
				_handle_left_click()
			else:
				_begin_select_drag()
		else:
			_finish_select_drag()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _select_dragging:
				_select_dragging = false
				hud.hide_selection_drag()
			local_lane.tower_manager.cancel_build_mode()
			local_lane.placement_preview.hide_preview()
			hud.hide_build_hint()


func _handle_escape() -> void:
	if pause_menu.is_open():
		return
	if hud.close_pickers_if_open():
		get_viewport().set_input_as_handled()
		return
	var tm := local_lane.tower_manager
	if not tm.selected_towers.is_empty():
		tm.clear_selection()
		get_viewport().set_input_as_handled()
		return
	if tm.build_mode_tower_id != "":
		tm.cancel_build_mode()
		local_lane.placement_preview.hide_preview()
		hud.hide_build_hint()
		get_viewport().set_input_as_handled()
		return
	pause_menu.show_menu()
	get_viewport().set_input_as_handled()


func _on_forfeit_requested() -> void:
	_end_match(false)


func _on_main_menu_requested() -> void:
	GameConfig.match_active = false
	get_tree().paused = false
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _update_hover() -> void:
	var cell := _get_mouse_grid()
	if cell == _hover_cell:
		return
	_hover_cell = cell
	var tm := local_lane.tower_manager
	if tm.build_mode_tower_id != "":
		if not LaneCoords.is_buildable_interior(cell):
			local_lane.placement_preview.hide_preview()
			hud.hide_build_hint()
			return
		var check: Dictionary = local_lane.build_grid.can_place(cell, tm.build_mode_tower_id)
		var def: Dictionary = BalanceConfig.get_tower_def(tm.build_mode_tower_id)
		var c: Array = def.get("color", [0.5, 0.5, 0.5])
		local_lane.placement_preview.update_preview(cell, check.get("valid", false), Color(c[0], c[1], c[2]))
		if check.get("valid", false):
			hud.hide_build_hint()
		else:
			hud.show_build_hint(check.get("reason", "Invalid"))
	else:
		local_lane.placement_preview.hide_preview()
		hud.hide_build_hint()


func _handle_left_click() -> void:
	var cell := _get_mouse_grid()
	if not LaneCoords.is_buildable_interior(cell):
		return
	var tm := local_lane.tower_manager
	if tm.build_mode_tower_id == "":
		return
	_pending_place_cell = cell
	network.request_place_tower(cell, tm.build_mode_tower_id)


func notify_creep_spawned(lane: LaneController, creep: Node, net_id: int) -> void:
	if network:
		network.on_creep_spawned(lane, creep, net_id)


func notify_creep_removed(lane: LaneController, net_id: int) -> void:
	if network:
		network.on_creep_removed(lane, net_id)


func _refresh_local_tower_ui() -> void:
	var towers: Array = local_lane.tower_manager.selected_towers
	if towers.size() > 1:
		hud.show_multi_tower_info(towers)
	elif towers.size() == 1 and towers[0].has_method("get_display_info"):
		hud.show_tower_info(towers[0].get_display_info())
	else:
		hud.hide_tower_info()


func _begin_select_drag() -> void:
	_select_dragging = true
	_select_drag_start = get_viewport().get_mouse_position()


func _update_select_drag() -> void:
	var end := get_viewport().get_mouse_position()
	hud.update_selection_drag(_screen_rect_from_points(_select_drag_start, end))


func _finish_select_drag() -> void:
	if not _select_dragging:
		return
	_select_dragging = false
	hud.hide_selection_drag()
	var end := get_viewport().get_mouse_position()
	var drag_rect := _screen_rect_from_points(_select_drag_start, end)
	var tm := local_lane.tower_manager
	if drag_rect.size.length() < SELECT_DRAG_THRESHOLD:
		var cell := _get_mouse_grid()
		if LaneCoords.is_in_bounds(cell):
			tm.cancel_build_mode()
			tm.select_tower_at(cell)
			if tm.selected_tower:
				builder.move_to_grid(cell)
	else:
		tm.cancel_build_mode()
		var cam := get_viewport().get_camera_3d()
		tm.select_towers_in_screen_rect(cam, drag_rect)


func _screen_rect_from_points(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(a.x - b.x), absf(a.y - b.y))
	)


func _get_mouse_grid() -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2i(-1, -1)
	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	return local_lane.get_cell_from_ray(from, dir)


func _on_build_mode_changed(tower_id: String) -> void:
	hud.set_selected_tower(tower_id)
	if tower_id == "":
		local_lane.placement_preview.hide_preview()
		hud.hide_build_hint()
	else:
		_update_hover()


func _on_towers_selection_changed(towers: Array) -> void:
	if towers.is_empty():
		hud.hide_tower_info()
	elif towers.size() == 1 and towers[0].has_method("get_display_info"):
		hud.show_tower_info(towers[0].get_display_info())
	else:
		hud.show_multi_tower_info(towers)


func _on_placement_result(success: bool, message: String) -> void:
	var color := BrandColors.UI_SUCCESS if success else BrandColors.UI_DANGER
	hud.show_message(message, color)
	if success and _pending_place_cell.x >= 0:
		builder.move_to_grid(_pending_place_cell)
		_pending_place_cell = Vector2i(-1, -1)
	_refresh_local_tower_ui()


func _on_wave_started(wave_number: int, wave_data: Dictionary) -> void:
	var creep_id: String = wave_data.get("creep", "grunt")
	var def: Dictionary = BalanceConfig.get_creep_def(creep_id)
	var preview := "Wave %d: %d x %s (%s)" % [
		wave_number, wave_data.get("count", 0),
		def.get("display_name", creep_id), def.get("armor_type", "")
	]
	hud.update_wave(wave_number, preview)
	hud.show_message("Wave %d incoming!" % wave_number, BrandColors.UI_ACCENT)
	if NetworkManager.is_server():
		network.on_wave_started(wave_number, wave_data)


func _on_wave_preview(wave_number: int, wave_data: Dictionary) -> void:
	var creep_id: String = wave_data.get("creep", "grunt")
	var def: Dictionary = BalanceConfig.get_creep_def(creep_id)
	var preview := "Next: %d x %s (%s armor)" % [
		wave_data.get("count", 0),
		def.get("display_name", creep_id), def.get("armor_type", "")
	]
	hud.update_wave(_wave_display_number(wave_number), preview)
	if NetworkManager.is_server():
		network.on_wave_preview(wave_number, wave_data)


func _wave_display_number(preview_wave_number: int) -> int:
	if NetworkManager.is_online() and not NetworkManager.is_server():
		return maxi(preview_wave_number - 1, 0)
	return wave_coordinator.get_current_wave_number()


func _on_player_leak(_creep: Node, damage: int) -> void:
	hud.show_message("Leak! -%d core HP" % damage, BrandColors.UI_DANGER)


func _on_send_requested(package_id: String) -> void:
	network.request_send(package_id)


func _execute_send(package_id: String) -> void:
	var result: Dictionary = send_manager.purchase(package_id)
	var color := BrandColors.UI_SUCCESS if result.get("success") else BrandColors.UI_DANGER
	hud.show_message(result.get("reason", ""), color)
	hud.update_economy(local_lane.economy.gold, local_lane.economy.income)


func _on_send_released(_packages: Array, target_count: int) -> void:
	hud.show_send_status(target_count)


func _on_ai_lane_destroyed(lane: LaneController) -> void:
	hud.show_message("%s eliminated! Creeps will split to survivors." % lane.display_name, BrandColors.UI_ACCENT)
	if _active_ai_count() == 0:
		hud.show_message("All AI lanes defeated!", BrandColors.UI_SUCCESS)


func _on_creeps_redistributed(from_lane: LaneController, target_count: int) -> void:
	if _match_over or target_count <= 0:
		return
	hud.show_message(
		"Creeps from %s split across %d lane(s)" % [from_lane.display_name, target_count],
		BrandColors.UI_TEXT_MUTED
	)


func _on_ai_send_executed(ai_lane: LaneController, package_name: String, hit_player: bool) -> void:
	if not hit_player:
		return
	hud.show_message("%s sent %s!" % [ai_lane.display_name, package_name], BrandColors.UI_DANGER)


func _active_human_count() -> int:
	var count := 0
	for lane in human_lanes:
		if lane is LaneController and not lane.is_eliminated:
			count += 1
	return count


func _active_ai_count() -> int:
	var count := 0
	for lane in ai_lanes:
		if lane is LaneController and not lane.is_eliminated:
			count += 1
	return count


func _on_all_waves_complete() -> void:
	if _match_over:
		return
	await get_tree().create_timer(1.0).timeout
	while not _all_creeps_cleared() and not _match_over:
		await get_tree().create_timer(0.5).timeout
	if _match_over:
		return
	if NetworkManager.is_online():
		_end_match(true, true)
	else:
		_end_match(true)


func _on_undo_requested() -> void:
	if NetworkManager.is_online():
		hud.show_message("Undo is not available in multiplayer", BrandColors.UI_TEXT_MUTED)
		return
	local_lane.tower_manager.try_undo_sell()


func _on_local_lane_defeat() -> void:
	if NetworkManager.is_online():
		if NetworkManager.is_server():
			_check_ffa_winner()
			if _active_human_count() > 1:
				hud.show_message("You were eliminated!", BrandColors.UI_DANGER)
				return
		_end_match(false)
		return
	_end_match(false)


func _on_opponent_defeat() -> void:
	if not NetworkManager.is_online():
		return
	if NetworkManager.is_server():
		_check_ffa_winner()


func _check_ffa_winner() -> void:
	if _match_over:
		return
	var survivors: Array = []
	for lane in human_lanes:
		if lane is LaneController and not lane.is_eliminated:
			survivors.append(lane)
	if survivors.size() == 1:
		_end_match(survivors[0] == local_lane)
	elif survivors.is_empty():
		_end_match(false, true)


func _on_peer_disconnected(_peer_id: int) -> void:
	if _match_over or not NetworkManager.is_server():
		return
	hud.show_message("Opponent disconnected", BrandColors.UI_WARNING)
	_end_match(true)


func _end_match(victory: bool, mutual: bool = false) -> void:
	if _match_over:
		return
	var stats := _build_match_stats(victory)
	if NetworkManager.is_online() and NetworkManager.is_server():
		var winner_peer_id := _resolve_winner_peer_id(victory, mutual)
		network.on_match_end(winner_peer_id, stats)
	var local_victory := victory if not mutual else true
	_show_match_end(local_victory, stats)


func _resolve_winner_peer_id(victory: bool, mutual: bool) -> int:
	if mutual:
		return 0
	if victory:
		return NetworkManager.get_local_peer_id()
	for lane in human_lanes:
		if lane is LaneController and not lane.is_eliminated:
			return lane.control_peer_id
	if opponent_lane != null:
		return opponent_lane.control_peer_id
	return 0


func _show_match_end(victory: bool, stats: Dictionary) -> void:
	if _match_over:
		return
	_match_over = true
	GameConfig.match_active = false
	post_match.show_summary(victory, stats)
	GameConfig.match_ended.emit(victory, stats)


func _build_match_stats(victory: bool) -> Dictionary:
	var duration := Time.get_ticks_msec() / 1000.0 - GameConfig.match_start_time
	var tm := local_lane.tower_manager
	return {
		"victory": victory,
		"duration": duration,
		"final_wave": wave_coordinator.get_current_wave_number(),
		"total_leaks": local_lane.core.total_leaks,
		"gold_earned": local_lane.economy.total_gold_earned,
		"spent_towers": local_lane.economy.total_spent_towers,
		"spent_sends": local_lane.economy.total_spent_sends,
		"final_income": local_lane.economy.income,
		"top_tower": tm.get_top_damage_tower(),
		"main_leak_armor": local_lane.core.main_leak_armor,
		"ai_lanes_remaining": _active_ai_count()
	}


func _all_creeps_cleared() -> bool:
	for lane in human_lanes + ai_lanes:
		if lane is LaneController and not lane.is_eliminated:
			if lane.creep_spawner.active_creep_count() > 0:
				return false
	return true


func _restart_match() -> void:
	if NetworkManager.is_online():
		NetworkManager.return_to_lobby()
	else:
		get_tree().reload_current_scene()
