extends Control

## Dedicated server dashboard — stays on this screen; match sim runs in a hidden viewport.

@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var address_label: Label = $Panel/Margin/VBox/AddressLabel
@onready var phase_label: Label = $Panel/Margin/VBox/PhaseLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var log_label: Label = $Panel/Margin/VBox/LogLabel
@onready var match_host: SubViewport = $MatchHost

var _match_root: Node = null
var _phase: String = "starting"
var _started_at: float = 0.0
var _event_log: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	_configure_server_window()
	UIStyles.apply_panel($Panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.92)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	UIStyles.style_label(address_label, "muted")
	UIStyles.style_label(phase_label, "body")
	UIStyles.style_label(stats_label, "body")
	UIStyles.style_label(status_label, "muted")
	UIStyles.style_label(log_label, "muted")
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/TitleLabel.text = "MAZE WARS · SERVER"
	_log("Server panel started")
	NetworkManager.lobby_status_changed.connect(_on_status_changed)
	NetworkManager.lobby_updated.connect(_refresh_ui)
	NetworkManager.peer_connected.connect(func(id): _log("Peer %d connected" % id))
	NetworkManager.peer_disconnected.connect(func(id): _log("Peer %d disconnected" % id))
	GameConfig.match_ended.connect(_on_match_ended)
	NetworkManager.boot_dedicated_server_panel()


func _configure_server_window() -> void:
	DisplayServer.window_set_title("Maze Wars — Dedicated Server")
	DisplayServer.window_set_size(Vector2i(720, 560))
	DisplayServer.window_set_min_size(Vector2i(520, 420))


func _process(_delta: float) -> void:
	if _phase == "match":
		_refresh_match_stats()


func host_match_simulation(_player_count: int) -> void:
	if _match_root != null:
		return
	var match_scene: PackedScene = load(NetworkManager.MATCH_SCENE)
	_match_root = match_scene.instantiate()
	match_host.add_child(_match_root)
	_phase = "match"
	_log("Match started — %d players" % NetworkManager.match_player_count)
	_refresh_ui()


func unload_match_simulation() -> void:
	if _match_root != null:
		_match_root.queue_free()
		_match_root = null
	_phase = "lobby"
	_log("Returned to lobby")
	_refresh_ui()


func _on_status_changed(text: String) -> void:
	if not text.is_empty():
		status_label.text = text


func _on_match_ended(_victory: bool, _stats: Dictionary) -> void:
	_log("Match finished — returning to lobby in 5s")
	await get_tree().create_timer(5.0).timeout
	if NetworkManager.is_dedicated_server:
		NetworkManager.return_to_lobby()


func _log(message: String) -> void:
	var stamp := Time.get_time_string_from_system()
	_event_log.append("[%s] %s" % [stamp, message])
	while _event_log.size() > 12:
		_event_log.remove_at(0)
	print("[MazeWars Server] ", message)
	_refresh_ui()


func _refresh_ui() -> void:
	var host_ip := str(NetworkManager.host_address_hint)
	if host_ip.is_empty():
		host_ip = "starting..."
	address_label.text = "Address: %s:%d  ·  Uptime: %s" % [
		host_ip,
		NetworkManager.DEFAULT_PORT,
		_format_duration(Time.get_ticks_msec() / 1000.0 - _started_at),
	]
	if _phase == "match":
		phase_label.text = "IN MATCH"
		_refresh_match_stats()
	else:
		phase_label.text = "LOBBY — waiting for players"
		stats_label.text = "%d / %d players · need %d+ ready to auto-start" % [
			NetworkManager.get_lobby_player_count(),
			NetworkManager.MAX_LOBBY_PLAYERS,
			NetworkManager.MIN_PLAYERS_TO_START,
		]
	log_label.text = _build_log_text()


func _refresh_match_stats() -> void:
	if _match_root == null:
		return
	var wave := 0
	if _match_root.wave_coordinator:
		wave = _match_root.wave_coordinator.get_current_wave_number()
	var alive := 0
	for lane in _match_root.human_lanes:
		if lane is LaneController and not lane.is_eliminated:
			alive += 1
	var duration := 0.0
	if GameConfig.match_active:
		duration = Time.get_ticks_msec() / 1000.0 - GameConfig.match_start_time
	stats_label.text = "Wave %d  ·  %d lane(s) alive  ·  match time %s" % [
		wave, alive, _format_duration(duration)
	]


func _build_log_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Players:")
	for slot in NetworkManager.get_lobby_slots():
		if slot.is_empty():
			continue
		var ready_text := "ready" if slot.get("ready", false) else "not ready"
		lines.append("  · %s (peer %s) — %s" % [
			slot.get("name", "Player"),
			str(slot.get("peer_id", "?")),
			ready_text,
		])
	if NetworkManager.get_lobby_player_count() == 0 and _phase != "match":
		lines.append("  (no players connected)")
	lines.append("")
	lines.append("Log:")
	if _event_log.is_empty():
		lines.append("  (no events yet)")
	else:
		for entry in _event_log:
			lines.append("  %s" % entry)
	return "\n".join(lines)


func _format_duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var mins := total / 60
	var secs := total % 60
	return "%d:%02d" % [mins, secs]
