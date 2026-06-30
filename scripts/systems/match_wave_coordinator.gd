class_name MatchWaveCoordinator
extends Node

## Drives synchronized natural waves across every active lane.

signal wave_started(wave_number: int, wave_data: Dictionary)
signal wave_preview(wave_number: int, wave_data: Dictionary)
signal wave_countdown(seconds: float)
signal all_waves_complete

var lanes: Array = []
var wave_interval: float = 50.0
var current_wave_index: int = -1
var _countdown: float = 15.0
var _spawning: bool = false
var waves: Array = []


func setup(p_lanes: Array) -> void:
	lanes = p_lanes
	var eco: Dictionary = BalanceConfig.economy
	wave_interval = float(eco.get("wave_interval_seconds", 50.0))
	waves = BalanceConfig.get_wave_list()
	_countdown = 15.0
	_emit_preview(0)


func _process(delta: float) -> void:
	if _spawning:
		return
	if current_wave_index >= waves.size() - 1 and _all_lanes_clear():
		return
	_countdown -= delta
	wave_countdown.emit(maxf(_countdown, 0.0))
	if _countdown <= 0.0:
		_start_next_wave()


func _all_lanes_clear() -> bool:
	for lane in _active_lanes():
		if lane.creep_spawner.active_creep_count() > 0:
			return false
	return true


func _active_lanes() -> Array:
	return lanes.filter(func(l): return l is LaneController and not l.is_eliminated)


func _start_next_wave() -> void:
	if _spawning:
		return
	if current_wave_index >= waves.size() - 1:
		all_waves_complete.emit()
		_countdown = 9999.0
		return
	_spawning = true
	current_wave_index += 1
	var wave_data: Dictionary = waves[current_wave_index]
	var wave_number := current_wave_index + 1
	wave_started.emit(wave_number, wave_data)
	for lane in _active_lanes():
		lane.creep_spawner.spawn_wave(wave_data)
	_spawning = false
	_countdown = wave_interval
	var next_idx := current_wave_index + 1
	if next_idx < waves.size():
		_emit_preview(next_idx)


func _emit_preview(index: int) -> void:
	if index < waves.size():
		wave_preview.emit(index + 1, waves[index])


func force_start_wave() -> void:
	_countdown = 0.0


func get_current_wave_number() -> int:
	return current_wave_index + 1
