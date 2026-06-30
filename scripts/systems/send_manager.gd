class_name SendManager
extends Node

## Send packages — immediate release into enemy lanes (or own lane when last survivor).

signal send_purchased(package_data: Dictionary)
signal send_released(packages: Array, target_count: int)
signal send_timer(seconds_remaining: float)

const LaneControllerScript := preload("res://scripts/systems/lane_controller.gd")

var player_lane: LaneController
var enemy_lanes: Array = []
var economy: EconomyManager
var wave_coordinator: MatchWaveCoordinator


func setup(p_player: LaneController, p_enemies: Array, p_economy: EconomyManager, p_waves: MatchWaveCoordinator) -> void:
	player_lane = p_player
	enemy_lanes = p_enemies
	economy = p_economy
	wave_coordinator = p_waves


func _process(_delta: float) -> void:
	# Sends are instant; keep timer display off.
	send_timer.emit(-1.0)


func purchase(package_id: String) -> Dictionary:
	return purchase_for_lane(player_lane, _active_enemy_lanes(), package_id)


func purchase_for_lane(sender: LaneController, targets: Array, package_id: String) -> Dictionary:
	var pkg := _find_package(package_id)
	if pkg.is_empty():
		return { "success": false, "reason": "Unknown package" }
	var unlock_wave: int = int(pkg.get("unlock_wave", 1))
	if wave_coordinator.get_current_wave_number() < unlock_wave:
		return { "success": false, "reason": "Not unlocked yet" }
	var cost: int = int(pkg.get("cost", 0))
	if not sender.economy.spend(cost, "send"):
		return { "success": false, "reason": "Not enough gold" }
	var active_targets := _resolve_send_targets(targets, sender)
	if active_targets.is_empty():
		sender.economy.refund(cost)
		return { "success": false, "reason": "No lanes available to send to" }
	sender.economy.add_income(int(pkg.get("income_gain", 0)))
	_spawn_package_to_lanes(pkg, active_targets)
	send_purchased.emit(pkg)
	send_released.emit([pkg], active_targets.size())
	var pkg_name: String = pkg.get("display_name", "Send")
	var self_send: bool = active_targets.size() == 1 and active_targets[0] == sender
	return {
		"success": true,
		"reason": "Sent %s to your lane (training income)" % pkg_name if self_send else "Sent %s to %d lane(s)" % [pkg_name, active_targets.size()],
		"package": pkg,
		"target_count": active_targets.size(),
		"self_send": self_send
	}


func _spawn_package_to_lanes(pkg: Dictionary, lanes: Array) -> void:
	for lane in lanes:
		if _is_active_lane(lane):
			lane.spawn_send_package(pkg)


func _resolve_send_targets(targets: Array, sender: LaneController) -> Array:
	var active := _filter_active_lanes(targets)
	if not active.is_empty():
		return active
	# Player sends: fall back to cached enemy lanes or scene siblings.
	if sender != null and sender.is_player:
		active = _filter_active_lanes(enemy_lanes)
		if not active.is_empty():
			return active
		active = _discover_enemy_lanes(sender)
		if not active.is_empty():
			return active
	if _can_self_send(sender):
		return [sender]
	return []


func _can_self_send(sender: LaneController) -> bool:
	if sender == null or not _is_active_lane(sender):
		return false
	return _active_lane_count() == 1


func _active_lane_count() -> int:
	var count := 0
	for lane in _all_lanes():
		if _is_active_lane(lane):
			count += 1
	return count


func _all_lanes() -> Array:
	var lanes: Array = []
	if player_lane != null:
		lanes.append(player_lane)
	for lane in enemy_lanes:
		if lane not in lanes:
			lanes.append(lane)
	return lanes


func _discover_enemy_lanes(sender: LaneController) -> Array:
	var found: Array = []
	var lanes_root := sender.get_parent()
	if lanes_root == null:
		return found
	for child in lanes_root.get_children():
		if child == sender:
			continue
		if _is_active_lane(child) and not child.is_player:
			found.append(child)
	return found


func _is_active_lane(lane) -> bool:
	if lane == null or not is_instance_valid(lane):
		return false
	if not lane.has_method("spawn_send_package"):
		return false
	if lane.is_eliminated:
		return false
	return true


func _filter_active_lanes(lanes: Array) -> Array:
	var result: Array = []
	for lane in lanes:
		if _is_active_lane(lane):
			result.append(lane)
	return result


func _active_enemy_lanes() -> Array:
	return _resolve_send_targets(enemy_lanes, player_lane)


func force_release() -> void:
	pass


func get_available_packages() -> Array:
	var result: Array = []
	var current_wave := wave_coordinator.get_current_wave_number() if wave_coordinator else 1
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		var copy: Dictionary = pkg.duplicate(true)
		copy["unlocked"] = current_wave >= int(pkg.get("unlock_wave", 1))
		result.append(copy)
	return result


func _find_package(package_id: String) -> Dictionary:
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		if pkg.get("id", "") == package_id:
			return pkg
	return {}
