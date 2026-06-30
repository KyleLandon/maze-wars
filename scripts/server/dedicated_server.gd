extends Control

## Headless dedicated server status screen (no gameplay UI).

@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var log_label: Label = $Panel/Margin/VBox/LogLabel


func _ready() -> void:
	UIStyles.apply_panel($Panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.85)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	UIStyles.style_label(status_label, "body")
	UIStyles.style_label(log_label, "muted")
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/TitleLabel.text = "MAZE WARS · DEDICATED SERVER"
	status_label.text = NetworkManager.lobby_status
	log_label.text = _build_log_text()
	NetworkManager.lobby_status_changed.connect(_on_status_changed)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.peer_connected.connect(func(_id): _on_lobby_updated())
	NetworkManager.peer_disconnected.connect(func(_id): _on_lobby_updated())


func _on_status_changed(text: String) -> void:
	status_label.text = text


func _on_lobby_updated() -> void:
	log_label.text = _build_log_text()


func _build_log_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"Listening on UDP %d · auto-starts when %d–%d players are all ready." % [
			NetworkManager.DEFAULT_PORT,
			NetworkManager.MIN_PLAYERS_TO_START,
			NetworkManager.MAX_LOBBY_PLAYERS,
		]
	)
	lines.append("")
	for slot in NetworkManager.get_lobby_slots():
		if slot.is_empty():
			continue
		var ready_text := "ready" if slot.get("ready", false) else "not ready"
		lines.append(
			"· %s (peer %s) — %s" % [
				slot.get("name", "Player"),
				str(slot.get("peer_id", "?")),
				ready_text,
			]
		)
	if NetworkManager.get_lobby_player_count() == 0:
		lines.append("Waiting for players to connect...")
	return "\n".join(lines)
