extends Node

## Routes to main menu or dedicated server based on launch args.


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	if _is_dedicated_server():
		get_tree().change_scene_to_file("res://scenes/server/dedicated_server.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _is_dedicated_server() -> bool:
	for arg in OS.get_cmdline_args():
		if arg in ["--dedicated-server", "--server"]:
			return true
	return false
