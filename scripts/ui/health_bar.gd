extends Node3D

## Billboard health bar above creeps.

var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D
var _target: Node3D
var _bar_width: float = 1.0


func setup(target: Node3D) -> void:
	_target = target
	position = Vector3(0, 1.4, 0)
	_bar_bg = _make_bar(Color(0.15, 0.15, 0.15, 0.8), _bar_width)
	_bar_fill = _make_bar(Color(0.2, 0.85, 0.3), _bar_width)
	add_child(_bar_bg)
	add_child(_bar_fill)


func _make_bar(color: Color, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.12, 0.08)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	return mi


func update_health(current: float, maximum: float) -> void:
	if maximum <= 0:
		return
	var pct := clampf(current / maximum, 0.0, 1.0)
	_bar_fill.scale.x = pct
	_bar_fill.position.x = -_bar_width * 0.5 * (1.0 - pct)
	if pct < 0.3:
		var mat: StandardMaterial3D = _bar_fill.material_override
		mat.albedo_color = BrandColors.UI_DANGER


func _process(_delta: float) -> void:
	if _target and is_instance_valid(_target):
		look_at(_target.global_position + Vector3(0, 0, -1), Vector3.UP)
