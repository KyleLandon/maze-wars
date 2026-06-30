extends Node

## ENet host/join for 2-player LAN matches.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed
signal server_started
signal connected_to_server
signal lobby_status_changed(text: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const MATCH_SCENE := "res://scenes/match/match.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CONNECT_TIMEOUT_SEC := 20.0
const CLIENT_LOAD_FALLBACK_SEC := 3.0
## Bump when multiplayer RPC signatures change (not every app version).
const NET_PROTOCOL_VERSION := 2

var multiplayer_mode: String = "solo"
var is_host: bool = false
var lobby_status: String = ""
var host_address_hint: String = ""

var _connect_started_at: float = -1.0
var _client_load_timer: float = -1.0
var _match_loading: bool = false
var _match_network: Node = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if multiplayer_mode == "client" and _connect_started_at >= 0.0:
		_poll_client_connection(delta)
	elif multiplayer_mode == "client" and _client_load_timer >= 0.0:
		_client_load_timer -= delta
		if _client_load_timer <= 0.0:
			_client_load_timer = -1.0
			_client_load_match_fallback()


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
	host_address_hint = get_lan_ip()
	_try_upnp_port(port)
	server_started.emit()
	_set_status(
		"HOSTING on %s:%d\nGive guest this IP, then wait.\nAllow firewall if Windows asks." % [
			host_address_hint, port
		]
	)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_match_loading = false
	var trimmed := address.strip_edges()
	if trimmed.is_empty():
		_set_status("Enter the host IP address first.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(trimmed, port)
	if err != OK:
		_set_status("Failed to connect to %s:%d" % [trimmed, port])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer_mode = "client"
	is_host = false
	_connect_started_at = Time.get_ticks_msec() / 1000.0
	_set_status("Connecting to %s:%d ..." % [trimmed, port])
	return OK


func disconnect_game() -> void:
	_connect_started_at = -1.0
	_client_load_timer = -1.0
	_match_loading = false
	_match_network = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	multiplayer_mode = "solo"
	is_host = false
	host_address_hint = ""
	_set_status("")


func start_solo() -> void:
	disconnect_game()
	get_tree().change_scene_to_file(MATCH_SCENE)


func begin_online_match() -> void:
	if not is_online() or _match_loading:
		return
	if not multiplayer.is_server():
		return
	_match_loading = true
	rpc_load_match.rpc()


func register_match_network(net: Node) -> void:
	_match_network = net


func unregister_match_network() -> void:
	_match_network = null


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
func report_client_build(protocol: int, build_label: String) -> void:
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
	_set_status("Guest v%s ready. Starting match..." % _base_version(build_label))
	begin_online_match()


@rpc("authority", "call_remote", "reliable")
func rpc_kick_with_message(message: String) -> void:
	_set_status(message)
	connection_failed.emit()
	disconnect_game()
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


@rpc("authority", "call_remote", "call_local", "reliable")
func rpc_load_match() -> void:
	_match_loading = true
	if get_tree().current_scene == null:
		return
	var path := get_tree().current_scene.scene_file_path
	if path == MATCH_SCENE:
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func _poll_client_connection(_delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	var status: int = peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		_connect_started_at = -1.0
		return
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_fail_connection("Disconnected before the match could start.")
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _connect_started_at
	if elapsed >= CONNECT_TIMEOUT_SEC:
		_fail_connection(
			"Connection timed out.\nCheck host IP, same Wi‑Fi, and host firewall (UDP %d)." % DEFAULT_PORT
		)


func _fail_connection(message: String) -> void:
	_connect_started_at = -1.0
	_client_load_timer = -1.0
	disconnect_game()
	_set_status(message)
	connection_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	_set_status("Guest connected (%d). Checking version..." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	_set_status("Player disconnected (%d)" % peer_id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()
	_connect_started_at = -1.0
	report_client_build.rpc_id(1, NET_PROTOCOL_VERSION, GameVersion.version_label)
	_set_status("Connected. Waiting for host...")
	_client_load_timer = CLIENT_LOAD_FALLBACK_SEC


func _client_load_match_fallback() -> void:
	if multiplayer_mode != "client" or _match_loading:
		return
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == MATCH_SCENE:
		return
	_match_loading = true
	_set_status("Starting match...")
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_connection_failed() -> void:
	_fail_connection("Connection failed. Check IP and firewall.")


func _on_server_disconnected() -> void:
	disconnect_game()
	_set_status("Disconnected from host")
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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
