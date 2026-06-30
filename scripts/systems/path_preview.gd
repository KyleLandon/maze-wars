class_name PathPreview
extends Node3D

## Draws the current creep path as a line in 3D.

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = BrandColors.PATH_VALID
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = _material


func show_path(waypoints: Array) -> void:
	if waypoints.is_empty():
		_mesh_instance.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for wp: Vector3 in waypoints:
		im.surface_add_vertex(wp + Vector3(0, 0.15, 0))
	im.surface_end()
	_mesh_instance.mesh = im
