extends Node

## Global game settings and match state flags.

signal match_ended(victory: bool, stats: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"

var match_active: bool = false
var match_start_time: float = 0.0
var debug_mode: bool = true
var master_volume: float = 1.0
var player_name: String = "Player"
var last_server_address: String = ""


func _ready() -> void:
	load_settings()


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
