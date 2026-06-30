extends StaticBody3D

## Grid-placed tower with targeting, upgrades, and sell.

signal upgraded(level: int)
signal sold

const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")

var tower_id: String = ""
var owner_id: String = "player"
var grid_cell: Vector2i = Vector2i.ZERO
var level: int = 1
var max_level: int = 3

var base_damage: float = 10.0
var damage: float = 10.0
var attack_speed: float = 1.0
var attack_range: int = 3
var damage_type: String = "physical"
var targeting: String = "closest"
var projectile_speed_tiles: float = 8.0
var splash_tiles: int = 0
var slow_percent: float = 0.0
var slow_duration: float = 0.0

var total_invested: int = 0
var _attack_cooldown: float = 0.0
var _creep_spawner: CreepSpawner
var _tower_manager: TowerManager
var _selection_indicator: MeshInstance3D


func setup(
	p_tower_id: String,
	p_grid: Vector2i,
	p_owner: String,
	p_spawner: CreepSpawner,
	p_manager: TowerManager
) -> void:
	tower_id = p_tower_id
	grid_cell = p_grid
	owner_id = p_owner
	_creep_spawner = p_spawner
	_tower_manager = p_manager
	_apply_base_stats()
	total_invested = int(BalanceConfig.get_tower_def(tower_id).get("cost", 0))
	position = LaneCoords.grid_to_world_center(grid_cell)
	position.y = 0.0
	_build_visual()
	_build_selection_indicator()


func _apply_base_stats() -> void:
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	base_damage = float(def.get("damage", 10))
	damage = base_damage
	attack_speed = float(def.get("attack_speed", 1.0))
	attack_range = int(def.get("range", 3))
	damage_type = str(def.get("damage_type", "physical"))
	targeting = str(def.get("targeting", "closest"))
	projectile_speed_tiles = float(def.get("projectile_speed", 8.0))
	splash_tiles = int(def.get("splash_radius", 0))
	slow_percent = float(def.get("slow_percent", 0.0))
	slow_duration = float(def.get("slow_duration", 0.0))


func _build_visual() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	var mesh_inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var height: float = float(def.get("height", 2.5)) + (level - 1) * 0.3
	mesh.top_radius = 0.6 + level * 0.05
	mesh.bottom_radius = 0.8 + level * 0.05
	mesh.height = height
	mesh_inst.mesh = mesh
	mesh_inst.position.y = height * 0.5
	var mat := StandardMaterial3D.new()
	var c: Array = def.get("color", [0.5, 0.5, 0.5])
	mat.albedo_color = Color(c[0], c[1], c[2])
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _build_selection_indicator() -> void:
	if _selection_indicator:
		_selection_indicator.queue_free()
	_selection_indicator = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var cell := LaneCoords.cell_size
	mesh.size = Vector3(cell * 0.92, 0.04, cell * 0.92)
	_selection_indicator.mesh = mesh
	_selection_indicator.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(BrandColors.NEON_CYAN.r, BrandColors.NEON_CYAN.g, BrandColors.NEON_CYAN.b, 0.22)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_indicator.material_override = mat
	_selection_indicator.visible = false
	add_child(_selection_indicator)


func _process(delta: float) -> void:
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_at(target)
	_attack_cooldown = 1.0 / attack_speed


func _find_target() -> Node3D:
	if _creep_spawner == null:
		return null
	var creeps := _creep_spawner.get_active_creeps()
	var best: Node3D = null
	var best_val: float = INF if targeting == "closest" else -1.0
	for creep in creeps:
		if not is_instance_valid(creep):
			continue
		var creep_cell := LaneCoords.world_to_grid(creep.global_position)
		var tile_dist := LaneCoords.grid_tile_distance(grid_cell, creep_cell)
		if tile_dist > attack_range:
			continue
		match targeting:
			"closest":
				if float(tile_dist) < best_val:
					best_val = float(tile_dist)
					best = creep
			"highest_hp":
				if creep.current_health > best_val:
					best_val = creep.current_health
					best = creep
	return best


func _fire_at(target: Node3D) -> void:
	var proj: Area3D = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 2.0, 0)
	proj.setup(
		target,
		damage,
		damage_type,
		LaneCoords.tile_speed_to_world(projectile_speed_tiles),
		tower_id,
		_creep_spawner,
		splash_tiles,
		slow_percent,
		slow_duration
	)


func try_upgrade(economy: EconomyManager) -> Dictionary:
	if level >= max_level:
		return { "success": false, "reason": "Max level" }
	var next_level := level + 1
	var upg: Dictionary = BalanceConfig.get_upgrade_def(tower_id, next_level)
	if upg.is_empty():
		return { "success": false, "reason": "No upgrade defined" }
	var cost: int = int(upg.get("cost", 0))
	if not economy.spend(cost, "tower"):
		return { "success": false, "reason": "Not enough gold" }
	total_invested += cost
	level = next_level
	_apply_upgrade(upg)
	upgraded.emit(level)
	return { "success": true, "reason": "Upgraded to level %d" % level }


func _apply_upgrade(upg: Dictionary) -> void:
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	base_damage = float(def.get("damage", 10))
	damage = base_damage * float(upg.get("damage_mult", 1.0))
	attack_speed = float(def.get("attack_speed", 1.0)) * float(upg.get("attack_speed_mult", 1.0))
	attack_range = maxi(1, roundi(float(def.get("range", 3)) * float(upg.get("range_mult", 1.0))))
	if upg.has("splash_radius_mult"):
		splash_tiles = maxi(0, roundi(float(def.get("splash_radius", 0)) * float(upg.get("splash_radius_mult", 1.0))))
	if upg.has("slow_percent_add"):
		slow_percent = float(def.get("slow_percent", 0.0)) + float(upg.get("slow_percent_add", 0.0))
	_build_visual()
	_build_selection_indicator()


func get_sell_value() -> int:
	var refund_pct: float = float(BalanceConfig.economy.get("sell_refund_percent", 0.7))
	return int(total_invested * refund_pct)


func get_upgrade_cost() -> int:
	if level >= max_level:
		return -1
	return int(BalanceConfig.get_upgrade_def(tower_id, level + 1).get("cost", 0))


func get_undo_snapshot() -> Dictionary:
	return {
		"tower_id": tower_id,
		"grid_cell": grid_cell,
		"level": level,
		"total_invested": total_invested,
		"damage": damage,
		"base_damage": base_damage,
		"attack_speed": attack_speed,
		"attack_range": attack_range,
		"projectile_speed_tiles": projectile_speed_tiles,
		"splash_tiles": splash_tiles,
		"slow_percent": slow_percent,
		"refund": get_sell_value()
	}


func restore_snapshot(state: Dictionary) -> void:
	level = int(state.get("level", 1))
	total_invested = int(state.get("total_invested", 0))
	damage = float(state.get("damage", damage))
	base_damage = float(state.get("base_damage", base_damage))
	attack_speed = float(state.get("attack_speed", attack_speed))
	attack_range = int(state.get("attack_range", attack_range))
	projectile_speed_tiles = float(state.get("projectile_speed_tiles", projectile_speed_tiles))
	splash_tiles = int(state.get("splash_tiles", state.get("splash_radius", splash_tiles)))
	slow_percent = float(state.get("slow_percent", slow_percent))
	_build_visual()
	_build_selection_indicator()


func try_sell(economy: EconomyManager, build_grid: BuildGrid) -> Dictionary:
	var value := get_sell_value()
	build_grid.unregister_tower(grid_cell)
	economy.refund(value)
	sold.emit()
	queue_free()
	return { "success": true, "reason": "Sold for %d gold" % value }


func set_selected(selected: bool) -> void:
	if _selection_indicator:
		_selection_indicator.visible = selected


func get_display_info() -> Dictionary:
	var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
	return {
		"name": def.get("display_name", tower_id),
		"level": level,
		"damage": damage,
		"attack_speed": attack_speed,
		"range": attack_range,
		"damage_type": damage_type,
		"targeting": targeting,
		"upgrade_cost": get_upgrade_cost(),
		"sell_value": get_sell_value(),
		"owner": owner_id,
		"slow_percent": slow_percent
	}
