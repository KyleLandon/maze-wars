extends Node

## Global game settings and match state flags.

signal match_ended(victory: bool, stats: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"
const NETWORK_CONFIG_PATH := "res://config/network.json"
const USER_NETWORK_OVERRIDE_PATH := "user://network.json"

var match_active: bool = false
var match_start_time: float = 0.0
var debug_mode: bool = true
var master_volume: float = 1.0
var player_name: String = "Player"
var last_server_address: String = ""
var network: Dictionary = {}


func _ready() -> void:
	load_network_config()
	load_settings()


func load_network_config() -> void:
	network = _load_json(NETWORK_CONFIG_PATH)
	if FileAccess.file_exists(USER_NETWORK_OVERRIDE_PATH):
		var override: Dictionary = _load_json(USER_NETWORK_OVERRIDE_PATH)
		for key in override.keys():
			network[key] = override[key]


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func get_default_server_address() -> String:
	return str(network.get("default_server_address", "")).strip_edges()


func get_server_display_name() -> String:
	return str(network.get("server_display_name", "Maze Wars Server")).strip_edges()


func get_configured_server_port() -> int:
	return int(network.get("server_port", 7777))


func has_default_server() -> bool:
	return not get_default_server_address().is_empty()


func get_local_join_address() -> String:
	return str(network.get("local_join_address", "127.0.0.1")).strip_edges()


func get_join_server_address() -> String:
	if has_default_server():
		var last := get_last_server_address()
		if not last.is_empty():
			return last
		return get_default_server_address()
	var last := get_last_server_address()
	if not last.is_empty():
		return last
	return ""


func get_lan_server_address() -> String:
	return _detect_lan_ip()


func get_server_address_hint() -> String:
	var configured := get_default_server_address()
	if not configured.is_empty():
		return configured
	return _detect_lan_ip()


func _detect_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.contains(".") and not addr.begins_with("127."):
			return addr
	return "127.0.0.1"


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		player_name = _default_player_name()
		apply_audio_settings()
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	player_name = str(cfg.get_value("player", "name", _default_player_name()))
	last_server_address = str(cfg.get_value("network", "last_server_address", ""))
	apply_audio_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("network", "last_server_address", last_server_address)
	cfg.save(SETTINGS_PATH)


func get_last_server_address() -> String:
	return last_server_address.strip_edges()


func set_last_server_address(address: String) -> void:
	last_server_address = address.strip_edges()
	save_settings()


func get_player_name() -> String:
	var trimmed := player_name.strip_edges()
	if trimmed.is_empty():
		return _default_player_name()
	return trimmed.substr(0, 20)


func set_player_name(name: String) -> void:
	player_name = name.strip_edges().substr(0, 20)
	save_settings()


func _default_player_name() -> String:
	var user := OS.get_environment("USERNAME")
	if user.is_empty():
		user = OS.get_environment("USER")
	if user.is_empty():
		return "Player"
	return user.substr(0, 20)


func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	apply_audio_settings()


func apply_audio_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume) if master_volume > 0.0 else -80.0)
