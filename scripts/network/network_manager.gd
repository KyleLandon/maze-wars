extends Node

## ENet host/join, lobby, and dedicated-server entry for 2–4 player FFA.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed
signal server_started
signal connected_to_server
signal lobby_status_changed(text: String)
signal lobby_updated

const DEFAULT_PORT := 7777
const MAX_LOBBY_PLAYERS := 4
const MAX_CLIENTS := MAX_LOBBY_PLAYERS - 1
const MIN_PLAYERS_TO_START := 2
const MATCH_SCENE := "res://scenes/match/match.tscn"
const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"
const DEDICATED_SERVER_SCENE := "res://scenes/server/dedicated_server.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CONNECT_TIMEOUT_SEC := 8.0
const CLIENT_LOBBY_FALLBACK_SEC := 4.0
## Bump when multiplayer RPC signatures change (not every app version).
const NET_PROTOCOL_VERSION := 3

var multiplayer_mode: String = "solo"
var is_host: bool = false
var is_dedicated_server: bool = false
var lobby_status: String = ""
var host_address_hint: String = ""
var in_lobby: bool = false
var match_player_count: int = 2

var _connect_started_at: float = -1.0
var _client_lobby_timer: float = -1.0
var _match_loading: bool = false
var _match_network: Node = null
var _lobby_players: Dictionary = {}
var _join_candidates: PackedStringArray = PackedStringArray()
var _join_candidate_index: int = 0
var _join_port: int = DEFAULT_PORT


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if _is_dedicated_server_arg():
		is_dedicated_server = true


func _process(delta: float) -> void:
	if multiplayer_mode == "client" and _connect_started_at >= 0.0:
		_poll_client_connection(delta)
	elif multiplayer_mode == "client" and _client_lobby_timer >= 0.0:
		_client_lobby_timer -= delta
		if _client_lobby_timer <= 0.0:
			_client_lobby_timer = -1.0
			_client_lobby_fallback()


func is_online() -> bool:
	return multiplayer_mode != "solo"


func is_server() -> bool:
	return is_online() and multiplayer.is_server()


func get_local_peer_id() -> int:
	if not is_online():
		return 1
	return multiplayer.get_unique_id()


func get_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.contains(".") and not addr.begins_with("127."):
			return addr
	return "127.0.0.1"


func get_lobby_player_count() -> int:
	return _lobby_players.size()


func get_lobby_slots() -> Array:
	var slots: Array = []
	var ordered: Array = _lobby_players.values()
	ordered.sort_custom(func(a, b): return a.peer_id < b.peer_id)
	for player in ordered:
		slots.append(player.to_dict())
	while slots.size() < MAX_LOBBY_PLAYERS:
		slots.append({})
	return slots


func can_press_start() -> bool:
	return is_server() and not is_dedicated_server and in_lobby


func can_start_match() -> bool:
	return _can_start_match()


func is_local_ready() -> bool:
	var player: LobbyPlayer = _lobby_players.get(get_local_peer_id())
	return player != null and player.ready


func host_game(port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_match_loading = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_set_status("Failed to host on port %d" % port)
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer_mode = "host"
	is_host = true
	host_address_hint = GameConfig.get_server_address_hint()
	_try_upnp_port(port)
	server_started.emit()
	if is_dedicated_server:
		_set_status("Dedicated server on %s:%d" % [host_address_hint, port])
	else:
		_set_status(
			"Hosting lobby on %s:%d\nShare this IP — up to %d players." % [
				host_address_hint, port, MAX_LOBBY_PLAYERS
			]
		)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	_match_loading = false
	_join_candidates = _build_join_candidates(address)
	_join_candidate_index = 0
	_join_port = port
	if _join_port == DEFAULT_PORT and GameConfig.get_configured_server_port() != DEFAULT_PORT:
		_join_port = GameConfig.get_configured_server_port()
	if _join_candidates.is_empty():
		_set_status("Enter the server IP address first.")
		return ERR_INVALID_PARAMETER
	return _connect_join_candidate()


func _build_join_candidates(address: String) -> PackedStringArray:
	var candidates: PackedStringArray = PackedStringArray()
	var trimmed := address.strip_edges()
	if trimmed.is_empty():
		trimmed = GameConfig.get_default_server_address()
	if trimmed.is_empty():
		return candidates
	candidates.append(trimmed)
	# Public IP often fails on the same PC (no hairpin NAT) — try loopback + LAN next.
	if trimmed == GameConfig.get_default_server_address():
		var loopback := GameConfig.get_local_join_address()
		if not loopback.is_empty() and loopback != trimmed and not candidates.has(loopback):
			candidates.append(loopback)
		var lan := GameConfig.get_lan_server_address()
		if not lan.is_empty() and lan != trimmed and lan != loopback and not candidates.has(lan):
			candidates.append(lan)
	return candidates


func _connect_join_candidate() -> Error:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	multiplayer_mode = "solo"
	is_host = false
	in_lobby = false
	_lobby_players.clear()
	_client_lobby_timer = -1.0

	var trimmed := _join_candidates[_join_candidate_index]
	GameConfig.set_last_server_address(trimmed)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(trimmed, _join_port)
	if err != OK:
		_set_status("Failed to connect to %s:%d" % [trimmed, _join_port])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer_mode = "client"
	is_host = false
	_connect_started_at = Time.get_ticks_msec() / 1000.0
	if _join_candidates.size() > 1:
		_set_status(
			"Connecting to %s:%d ... (try %d of %d)" % [
				trimmed, _join_port, _join_candidate_index + 1, _join_candidates.size()
			]
		)
	else:
		_set_status("Connecting to %s:%d ..." % [trimmed, _join_port])
	return OK


func _try_next_join_candidate() -> bool:
	if _join_candidates.is_empty():
		return false
	_join_candidate_index += 1
	if _join_candidate_index >= _join_candidates.size():
		return false
	_connect_join_candidate()
	return true


func disconnect_game() -> void:
	_connect_started_at = -1.0
	_client_lobby_timer = -1.0
	_join_candidates.clear()
	_join_candidate_index = 0
	_match_loading = false
	_match_network = null
	in_lobby = false
	_lobby_players.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	multiplayer_mode = "solo"
	is_host = false
	host_address_hint = ""
	_set_status("")
	lobby_updated.emit()


func start_solo() -> void:
	disconnect_game()
	get_tree().change_scene_to_file(MATCH_SCENE)


func enter_lobby() -> void:
	if not is_online() or not multiplayer.is_server():
		return
	in_lobby = true
	_ensure_host_in_lobby()
	_broadcast_lobby()
	if is_dedicated_server:
		lobby_updated.emit()
		return
	rpc_load_lobby.rpc()
	_enter_lobby_scene()


func boot_dedicated_server_panel() -> void:
	if multiplayer_mode != "solo":
		return
	is_dedicated_server = true
	var err := host_game()
	if err != OK:
		push_error("Dedicated server failed to bind port %d" % DEFAULT_PORT)
		return
	enter_lobby()


func set_local_ready(ready: bool) -> void:
	if not in_lobby:
		return
	if is_server():
		_set_player_ready(get_local_peer_id(), ready)
	else:
		rpc_set_ready.rpc_id(1, ready)


func request_start_match() -> void:
	if not can_press_start() or not _can_start_match():
		return
	begin_online_match()


func return_to_lobby() -> void:
	if not is_online():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	_match_loading = false
	in_lobby = true
	_unload_dedicated_match()
	if is_server():
		for player in _lobby_players.values():
			player.ready = false
		_broadcast_lobby()
		if is_dedicated_server:
			lobby_updated.emit()
			return
		rpc_load_lobby.rpc()
	_enter_lobby_scene()


func begin_online_match() -> void:
	if not is_online() or _match_loading or not multiplayer.is_server():
		return
	if not _can_start_match():
		return
	match_player_count = _lobby_players.size()
	rpc_begin_match.rpc(match_player_count)
	_apply_begin_match(match_player_count)


func register_match_network(net: Node) -> void:
	_match_network = net


func unregister_match_network() -> void:
	_match_network = null


func leave_lobby() -> void:
	disconnect_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func server_place_tower(cx: int, cy: int, tower_id: String) -> void:
	if not is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _match_network == null:
		_retry_server_place(peer_id, cx, cy, tower_id)
		return
	_match_network.handle_place_request(peer_id, Vector2i(cx, cy), tower_id)


func _retry_server_place(peer_id: int, cx: int, cy: int, tower_id: String) -> void:
	for _i in 30:
		if _match_network != null:
			_match_network.handle_place_request(peer_id, Vector2i(cx, cy), tower_id)
			return
		await get_tree().process_frame
	if _match_network != null:
		_match_network.handle_place_request(peer_id, Vector2i(cx, cy), tower_id)
	elif peer_id > 0:
		push_warning("server_place_tower: match network unavailable for peer %d" % peer_id)


@rpc("any_peer", "call_remote", "reliable")
func server_upgrade(cells: PackedInt32Array) -> void:
	if not is_server() or _match_network == null:
		return
	_match_network.handle_upgrade_request(multiplayer.get_remote_sender_id(), cells)


@rpc("any_peer", "call_remote", "reliable")
func server_sell(cells: PackedInt32Array) -> void:
	if not is_server() or _match_network == null:
		return
	_match_network.handle_sell_request(multiplayer.get_remote_sender_id(), cells)


@rpc("any_peer", "call_remote", "reliable")
func server_send(package_id: String) -> void:
	if not is_server() or _match_network == null:
		return
	_match_network.handle_send_request(multiplayer.get_remote_sender_id(), package_id)


@rpc("any_peer", "call_remote", "reliable")
func report_client_build(protocol: int, build_label: String, player_name: String) -> void:
	if not is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if protocol != NET_PROTOCOL_VERSION:
		_reject_peer(
			peer_id,
			"Build mismatch (network protocol %d vs %d).\nUpdate both players with the launcher." % [
				protocol, NET_PROTOCOL_VERSION
			]
		)
		return
	if not _versions_compatible(build_label, GameVersion.version_label):
		_reject_peer(
			peer_id,
			"Version mismatch.\nHost: v%s\nGuest: v%s\nUse the launcher on both — do not mix editor F5 with an old export." % [
				GameVersion.version_label, build_label
			]
		)
		return
	_add_lobby_player(peer_id, _sanitize_player_name(player_name), build_label)
	_set_status("Guest %s joined lobby (%d/%d)" % [
		_sanitize_player_name(player_name), _lobby_players.size(), MAX_LOBBY_PLAYERS
	])
	rpc_load_lobby.rpc_id(peer_id)
	_broadcast_lobby()
	_check_auto_start()


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_ready(ready: bool) -> void:
	if not is_server():
		return
	_set_player_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("authority", "call_remote", "reliable")
func rpc_kick_with_message(message: String) -> void:
	_set_status(message)
	connection_failed.emit()
	disconnect_game()
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


@rpc("authority", "call_remote", "reliable")
func rpc_load_lobby() -> void:
	_enter_lobby_scene()


func _enter_lobby_scene() -> void:
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == LOBBY_SCENE:
		in_lobby = true
		return
	in_lobby = true
	_change_scene_deferred(LOBBY_SCENE)


func _change_scene_deferred(scene_path: String) -> void:
	call_deferred("_change_scene_now", scene_path)


func _change_scene_now(scene_path: String) -> void:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path:
		return
	get_tree().change_scene_to_file(scene_path)


@rpc("authority", "call_remote", "reliable")
func rpc_begin_match(player_count: int) -> void:
	_apply_begin_match(player_count)


func _apply_begin_match(player_count: int) -> void:
	match_player_count = maxi(MIN_PLAYERS_TO_START, player_count)
	_match_loading = true
	in_lobby = false
	if is_dedicated_server:
		if multiplayer.is_server():
			_start_dedicated_match_sim()
		return
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == MATCH_SCENE:
		return
	_change_scene_deferred(MATCH_SCENE)


func _start_dedicated_match_sim() -> void:
	var panel := get_tree().current_scene
	if panel != null and panel.has_method("host_match_simulation"):
		panel.host_match_simulation(match_player_count)


func _unload_dedicated_match() -> void:
	var panel := get_tree().current_scene
	if panel != null and panel.has_method("unload_match_simulation"):
		panel.unload_match_simulation()


@rpc("authority", "call_remote", "reliable")
func rpc_sync_lobby(lobby_json: String) -> void:
	_apply_lobby_json(lobby_json)
	lobby_updated.emit()


func _poll_client_connection(_delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	var status: int = peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		_connect_started_at = -1.0
		return
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _try_next_join_candidate():
			return
		_fail_connection("Disconnected before the lobby could load.")
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _connect_started_at
	if elapsed >= CONNECT_TIMEOUT_SEC:
		if _try_next_join_candidate():
			return
		var hint := "Check server is running, router port-forward (UDP %d), and Windows Firewall on the server PC." % _join_port
		if GameConfig.has_default_server():
			hint += "\nSame PC as server? Use 127.0.0.1. Same Wi‑Fi? Try LAN IP %s." % GameConfig.get_lan_server_address()
		_fail_connection("Connection timed out.\n%s" % hint)


func _fail_connection(message: String) -> void:
	_connect_started_at = -1.0
	_client_lobby_timer = -1.0
	_join_candidates.clear()
	_join_candidate_index = 0
	disconnect_game()
	_set_status(message)
	connection_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	if is_dedicated_server:
		_set_status("Player %d connected — checking version..." % peer_id)
	else:
		_set_status("Guest connected (%d). Checking version..." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	_lobby_players.erase(peer_id)
	if is_server():
		_broadcast_lobby()
	_set_status("Player disconnected (%d)" % peer_id)


func _on_connected_to_server() -> void:
	_join_candidates.clear()
	_join_candidate_index = 0
	connected_to_server.emit()
	_connect_started_at = -1.0
	_set_status("Connected. Joining lobby...")
	_client_lobby_timer = CLIENT_LOBBY_FALLBACK_SEC
	call_deferred("_send_client_hello")


func _send_client_hello() -> void:
	if multiplayer_mode != "client" or multiplayer.multiplayer_peer == null:
		return
	report_client_build.rpc_id(
		1, NET_PROTOCOL_VERSION, GameVersion.version_label, _local_player_name()
	)


func _client_lobby_fallback() -> void:
	if multiplayer_mode != "client" or _match_loading or in_lobby:
		return
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == LOBBY_SCENE:
		in_lobby = true
		return
	if _lobby_players.is_empty():
		_set_status("Connected but lobby did not load. Is the dedicated server running? Try 127.0.0.1.")
		return
	in_lobby = true
	_change_scene_deferred(LOBBY_SCENE)


func _on_connection_failed() -> void:
	if _try_next_join_candidate():
		return
	_fail_connection("Connection failed. Check IP and firewall.")


func _on_server_disconnected() -> void:
	disconnect_game()
	_set_status("Disconnected from host")
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _ensure_host_in_lobby() -> void:
	if is_dedicated_server:
		return
	var host_id := get_local_peer_id()
	if not _lobby_players.has(host_id):
		_add_lobby_player(host_id, _local_player_name(), GameVersion.version_label)


func _add_lobby_player(peer_id: int, player_name: String, version_label: String) -> void:
	var player := LobbyPlayer.new()
	player.peer_id = peer_id
	player.display_name = player_name
	player.ready = false
	player.version_label = version_label
	_lobby_players[peer_id] = player
	in_lobby = true


func _set_player_ready(peer_id: int, ready: bool) -> void:
	var player: LobbyPlayer = _lobby_players.get(peer_id)
	if player == null:
		return
	player.ready = ready
	_broadcast_lobby()
	_check_auto_start()


func _can_start_match() -> bool:
	if _lobby_players.size() < MIN_PLAYERS_TO_START:
		return false
	for player in _lobby_players.values():
		if not player.ready:
			return false
	return true


func _check_auto_start() -> void:
	if not is_dedicated_server or not is_server() or _match_loading:
		return
	if _can_start_match():
		begin_online_match()


func _broadcast_lobby() -> void:
	if not is_server():
		return
	var payload: Array = []
	for player in _lobby_players.values():
		payload.append(player.to_dict())
	rpc_sync_lobby.rpc(JSON.stringify(payload))
	lobby_updated.emit()


func _apply_lobby_json(lobby_json: String) -> void:
	_lobby_players.clear()
	var parsed: Variant = JSON.parse_string(lobby_json)
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				var player := LobbyPlayer.from_dict(entry)
				if player.peer_id > 0:
					_lobby_players[player.peer_id] = player
	in_lobby = true


func _local_player_name() -> String:
	return GameConfig.get_player_name()


func _sanitize_player_name(name: String) -> String:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return "Player"
	return trimmed.substr(0, 20)


func _is_dedicated_server_arg() -> bool:
	for arg in OS.get_cmdline_args():
		if arg in ["--dedicated-server", "--server"]:
			return true
	return false


func _try_upnp_port(port: int) -> void:
	if not ClassDB.class_exists("UPNP"):
		return
	var upnp: UPNP = UPNP.new()
	upnp.discover()
	upnp.add_port_mapping(port, port, "Maze Wars", "UDP")


func _set_status(text: String) -> void:
	lobby_status = text
	lobby_status_changed.emit(text)


func _base_version(label: String) -> String:
	return label.split("+")[0].strip_edges()


func _versions_compatible(a: String, b: String) -> bool:
	return _base_version(a) == _base_version(b)


func _reject_peer(peer_id: int, message: String) -> void:
	_set_status(message)
	rpc_kick_with_message.rpc_id(peer_id, message)
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.disconnect_peer(peer_id, true)
