extends Node

## Loads and caches JSON balance config from res://config/.

var lane: Dictionary = {}
var economy: Dictionary = {}
var towers: Dictionary = {}
var upgrades: Dictionary = {}
var waves: Dictionary = {}
var send_packages: Dictionary = {}
var damage_table: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	lane = _load_json("res://config/lane.json")
	economy = _load_json("res://config/economy.json")
	towers = _load_json("res://config/towers.json")
	upgrades = _load_json("res://config/upgrades.json")
	waves = _load_json("res://config/waves.json")
	send_packages = _load_json("res://config/send_packages.json")
	damage_table = _load_json("res://config/damage_table.json")


func get_damage_multiplier(damage_type: String, armor_type: String) -> float:
	var row: Dictionary = damage_table.get(damage_type, {})
	return float(row.get(armor_type, 1.0))


func get_tower_def(tower_id: String) -> Dictionary:
	return towers.get(tower_id, {})


func get_creep_def(creep_id: String) -> Dictionary:
	return waves.get("creeps", {}).get(creep_id, {})


func get_wave_list() -> Array:
	return waves.get("waves", [])


func get_send_package_list() -> Array:
	return send_packages.get("packages", [])


func get_upgrade_def(tower_id: String, level: int) -> Dictionary:
	return upgrades.get(tower_id, {}).get(str(level), {})


func roll_damage(base_damage: float) -> float:
	var min_mult := float(economy.get("damage_variance_min", 0.85))
	var max_mult := float(economy.get("damage_variance_max", 1.15))
	return base_damage * randf_range(min_mult, max_mult)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BalanceConfig: failed to load %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("BalanceConfig: invalid JSON in %s" % path)
		return {}
	return parsed
