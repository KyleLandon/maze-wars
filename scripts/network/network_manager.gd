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

var multiplayer_mode: String = "solo"
var is_host: bool = false
var lobby_status: String = ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return multiplayer_mode != "solo"


func is_server() -> bool:
	return is_online() and multiplayer.is_server()


func get_local_peer_id() -> int:
	if not is_online():
		return 1
	return multiplayer.get_unique_id()


func host_game(port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_set_status("Failed to host on port %d" % port)
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer_mode = "host"
	is_host = true
	server_started.emit()
	_set_status("Hosting on port %d — waiting for player..." % port)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		_set_status("Failed to connect to %s:%d" % [address, port])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer_mode = "client"
	is_host = false
	_set_status("Connecting to %s:%d..." % [address, port])
	return OK


func disconnect_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	multiplayer_mode = "solo"
	is_host = false
	_set_status("")


func start_solo() -> void:
	disconnect_game()
	get_tree().change_scene_to_file(MATCH_SCENE)


func begin_online_match() -> void:
	if not is_online():
		return
	rpc("rpc_load_match")


@rpc("call_local", "reliable")
func rpc_load_match() -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	_set_status("Player connected (%d). Starting match..." % peer_id)
	if is_server():
		call_deferred("begin_online_match")


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	_set_status("Player disconnected (%d)" % peer_id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()
	_set_status("Connected. Waiting for host...")


func _on_connection_failed() -> void:
	connection_failed.emit()
	disconnect_game()
	_set_status("Connection failed")


func _on_server_disconnected() -> void:
	disconnect_game()
	_set_status("Disconnected from host")
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _set_status(text: String) -> void:
	lobby_status = text
	lobby_status_changed.emit(text)
