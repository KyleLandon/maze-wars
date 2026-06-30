extends Node

## Reads build/version.txt (CI) or version.json (dev).

var version_label: String = "dev"


func _ready() -> void:
	version_label = _load_version_label()


func _load_version_label() -> String:
	var project_version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if not project_version.is_empty():
		return project_version

	var build_file := "res://build/version.txt"
	if FileAccess.file_exists(build_file):
		return FileAccess.get_file_as_string(build_file).strip_edges()

	var version_json := "res://version.json"
	if FileAccess.file_exists(version_json):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(version_json))
		if data is Dictionary:
			return str(data.get("display_name", data.get("version", "dev")))

	return "dev"
