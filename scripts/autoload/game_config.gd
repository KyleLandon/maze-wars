extends Node

## Global game settings and match state flags.

signal match_ended(victory: bool, stats: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"

var match_active: bool = false
var match_start_time: float = 0.0
var debug_mode: bool = true
var master_volume: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		apply_audio_settings()
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	apply_audio_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SETTINGS_PATH)


func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	apply_audio_settings()


func apply_audio_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume) if master_volume > 0.0 else -80.0)
