class_name LaneController
extends Node3D

const AILaneBrainScript := preload("res://scripts/systems/ai_lane_brain.gd")

## One playable lane — grid, pathing, towers, creeps, and core.

signal core_destroyed(lane: Node)
signal creep_leaked(creep: Node, damage: int)

var lane_id: String = ""
var display_name: String = ""
var is_player: bool = false
var is_eliminated: bool = false

var control_peer_id: int = 1

var lane_grid: LaneGrid
var path_manager: PathManager
var build_grid: BuildGrid
var creep_spawner: CreepSpawner
var economy: EconomyManager
var wave_manager: WaveManager
var tower_manager: TowerManager
var core: LaneCore
var path_preview: PathPreview
var placement_preview: PlacementPreview
var ai_brain: Node

var _lane_visual: Node3D
var _systems: Node
var _entities: Node3D


func setup(p_lane_id: String, p_display_name: String, p_is_player_lane: bool, p_peer_id: int = 1) -> void:
	lane_id = p_lane_id
	display_name = p_display_name
	is_player = p_is_player_lane
	control_peer_id = p_peer_id
	_build_lane_tree()
	_wire_systems()
	_place_core()
	if is_local_lane():
		_setup_player_visuals()
	elif is_player:
		_setup_opponent_visuals()
	else:
		_setup_ai_visuals()
		ai_brain = AILaneBrainScript.new()
		add_child(ai_brain)
		ai_brain.setup(self)


func is_local_lane() -> bool:
	if not NetworkManager.is_online():
		return is_player
	return control_peer_id == NetworkManager.get_local_peer_id()


func _build_lane_tree() -> void:
	_lane_visual = Node3D.new()
	_lane_visual.name = "LaneVisual"
	add_child(_lane_visual)

	lane_grid = LaneGrid.new()
	lane_grid.name = "LaneGrid"
	_lane_visual.add_child(lane_grid)

	path_preview = PathPreview.new()
	path_preview.name = "PathPreview"
	_lane_visual.add_child(path_preview)

	placement_preview = PlacementPreview.new()
	placement_preview.name = "PlacementPreview"
	_lane_visual.add_child(placement_preview)

	_systems = Node.new()
	_systems.name = "Systems"
	add_child(_systems)

	path_manager = PathManager.new()
	path_manager.name = "PathManager"
	_systems.add_child(path_manager)

	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	_systems.add_child(build_grid)

	economy = EconomyManager.new()
	economy.name = "EconomyManager"
	_systems.add_child(economy)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	_systems.add_child(wave_manager)

	tower_manager = TowerManager.new()
	tower_manager.name = "TowerManager"
	_systems.add_child(tower_manager)

	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)

	creep_spawner = CreepSpawner.new()
	creep_spawner.name = "CreepSpawner"
	_entities.add_child(creep_spawner)

	var core_scene: PackedScene = preload("res://scenes/entities/core.tscn")
	core = core_scene.instantiate()
	core.name = "Core"
	_entities.add_child(core)


func _wire_systems() -> void:
	path_manager.setup(lane_grid)
	build_grid.setup(lane_grid, path_manager)
	creep_spawner.setup(path_manager, economy)
	creep_spawner.owner_lane = self
	creep_spawner.tower_manager = tower_manager
	economy.setup()
	wave_manager.setup(creep_spawner)
	tower_manager.setup(build_grid, economy, creep_spawner)
	tower_manager.lane_root = _entities
	tower_manager.owner_id = lane_id
	wave_manager.set_process(false)
	core.setup()
	creep_spawner.creep_leaked.connect(_on_creep_leaked)
	core.destroyed.connect(_on_core_destroyed)


func _place_core() -> void:
	var core_pos := LaneCoords.grid_to_world_center(LaneCoords.exit_cell)
	core.position = core_pos


func _setup_player_visuals() -> void:
	path_preview.show_path(path_manager.current_waypoints)
	if not path_manager.path_updated.is_connected(path_preview.show_path):
		path_manager.path_updated.connect(path_preview.show_path)
	_add_zone_marker(LaneCoords.spawn_cell, BrandColors.SPAWN_ZONE)
	_add_zone_marker(LaneCoords.exit_cell, BrandColors.EXIT_ZONE)


func _setup_opponent_visuals() -> void:
	_add_lane_label()
	_add_zone_marker(LaneCoords.spawn_cell, Color(0.9, 0.35, 0.35, 0.25))
	_add_zone_marker(LaneCoords.exit_cell, Color(0.9, 0.35, 0.35, 0.25))


func _setup_ai_visuals() -> void:
	_add_lane_label()
	_add_zone_marker(LaneCoords.spawn_cell, Color(0.9, 0.35, 0.35, 0.25))
	_add_zone_marker(LaneCoords.exit_cell, Color(0.9, 0.35, 0.35, 0.25))


func _add_lane_label() -> void:
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 28
	label.position = LaneCoords.grid_to_world_center(LaneCoords.ai_label_cell) + Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.95, 0.55, 0.55)
	_lane_visual.add_child(label)


func _add_zone_marker(grid: Vector2i, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(LaneCoords.cell_size * 0.95, 0.1, LaneCoords.cell_size * 0.95)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	var pos := LaneCoords.grid_to_world_center(grid)
	pos.y = 0.05
	mi.position = pos
	_lane_visual.add_child(mi)


func get_cell_from_ray(origin: Vector3, direction: Vector3) -> Vector2i:
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null or not hit is Vector3:
		return Vector2i(-1, -1)
	return LaneCoords.world_to_grid(to_local(hit as Vector3))


func spawn_send_package(pkg: Dictionary) -> void:
	var contents: Variant = pkg.get("contents", [])
	if contents == null or not contents is Array:
		contents = []
	for entry in contents:
		if not entry is Dictionary:
			continue
		var wave_data := {
			"creep": entry.get("creep", "grunt"),
			"count": entry.get("count", 1),
			"interval": entry.get("interval", 0.5),
			"type": "send"
		}
		creep_spawner.spawn_wave(wave_data)


func _on_creep_leaked(creep: Node, damage: int) -> void:
	if is_eliminated:
		return
	core.take_leak_damage(damage, creep.armor_type if "armor_type" in creep else "")
	creep_leaked.emit(creep, damage)


func get_scoreboard_stats() -> Dictionary:
	return {
		"name": display_name,
		"is_player": is_player,
		"eliminated": is_eliminated,
		"kills": creep_spawner.kill_count,
		"total_income": economy.total_income_earned,
		"total_gold": economy.total_gold_earned,
		"core_current": 0 if is_eliminated else core.current_health,
		"core_max": core.max_health
	}


func _on_core_destroyed() -> void:
	if is_eliminated:
		return
	is_eliminated = true
	core_destroyed.emit(self)


func get_lane_width() -> float:
	return LaneCoords.lane_world_width()
