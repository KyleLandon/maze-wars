class_name LaneCore
extends StaticBody3D

## Lane core — takes damage from leaked creeps.

signal health_changed(current: int, maximum: int)
signal destroyed

var max_health: int = 100
var current_health: int = 100
var total_leaks: int = 0
var main_leak_armor: String = ""


func setup() -> void:
	max_health = int(BalanceConfig.economy.get("starting_core_health", 100))
	current_health = max_health
	health_changed.emit(current_health, max_health)


func apply_network_health(current: int, maximum: int) -> void:
	max_health = maximum
	current_health = current
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		destroyed.emit()


func take_leak_damage(amount: int, armor_type: String = "") -> void:
	current_health = maxi(current_health - amount, 0)
	total_leaks += 1
	if armor_type != "":
		main_leak_armor = armor_type
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		destroyed.emit()


func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)
