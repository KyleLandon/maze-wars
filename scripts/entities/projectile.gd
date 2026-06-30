extends Area3D

## Projectile fired by towers toward creeps.

var speed: float = 15.0
var damage: float = 10.0
var damage_type: String = "physical"
var target: Node3D
var source_tower_id: String = ""
var splash_tiles: int = 0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var _creep_spawner: CreepSpawner


func setup(
	p_target: Node3D,
	p_damage: float,
	p_damage_type: String,
	p_speed: float,
	p_tower_id: String,
	p_spawner: CreepSpawner,
	p_splash_tiles: int = 0,
	p_slow_pct: float = 0.0,
	p_slow_dur: float = 0.0
) -> void:
	target = p_target
	damage = p_damage
	damage_type = p_damage_type
	speed = p_speed
	source_tower_id = p_tower_id
	_creep_spawner = p_spawner
	splash_tiles = p_splash_tiles
	slow_percent = p_slow_pct
	slow_duration = p_slow_dur
	_build_visual()


func _build_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var to_target := target.global_position + Vector3(0, 0.8, 0) - global_position
	if to_target.length() < 0.4:
		_impact()
		return
	global_position += to_target.normalized() * speed * delta


func _impact() -> void:
	if splash_tiles > 0 and _creep_spawner:
		var impact_cell := LaneCoords.world_to_grid(global_position)
		for creep in _creep_spawner.get_active_creeps():
			if not is_instance_valid(creep):
				continue
			var creep_cell := LaneCoords.world_to_grid(creep.global_position)
			if LaneCoords.grid_tile_distance(impact_cell, creep_cell) <= splash_tiles:
				creep.take_damage(damage, damage_type, source_tower_id)
	elif is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, damage_type, source_tower_id)
		if slow_percent > 0.0 and target.has_method("apply_slow"):
			target.apply_slow(slow_percent, slow_duration)
	queue_free()
