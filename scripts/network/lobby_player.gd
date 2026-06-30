class_name LobbyPlayer
extends RefCounted

## One seat in a pre-match lobby.

var peer_id: int = 0
var display_name: String = "Player"
var ready: bool = false
var version_label: String = ""


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": display_name,
		"ready": ready,
		"version": version_label,
	}


static func from_dict(data: Dictionary) -> LobbyPlayer:
	var player := LobbyPlayer.new()
	player.peer_id = int(data.get("peer_id", 0))
	player.display_name = str(data.get("name", "Player"))
	player.ready = bool(data.get("ready", false))
	player.version_label = str(data.get("version", ""))
	return player
