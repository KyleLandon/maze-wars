extends Control

## Pre-match lobby — ready up, then host starts (or dedicated server auto-starts).

@onready var panel: PanelContainer = $Panel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var mode_label: Label = $Panel/Margin/VBox/ModeLabel
@onready var slots_row: HBoxContainer = $Panel/Margin/VBox/SlotsRow
@onready var ready_button: Button = $Panel/Margin/VBox/ReadyButton
@onready var start_button: Button = $Panel/Margin/VBox/StartButton
@onready var leave_button: Button = $Panel/Margin/VBox/LeaveButton
@onready var name_input: LineEdit = $Panel/Margin/VBox/NameRow/NameInput

var _slot_labels: Array = []
var _slot_status_labels: Array = []


func _ready() -> void:
	UIStyles.apply_panel(panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.55)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	$Panel/Margin/VBox/TitleLabel.text = "MATCH QUEUE"
	UIStyles.style_label(mode_label, "muted")
	UIStyles.style_label(status_label, "muted")
	UIStyles.style_label($Panel/Margin/VBox/NameRow/NameLabel, "muted")
	UIStyles.style_button(ready_button, "accent")
	UIStyles.style_button(start_button, "accent")
	UIStyles.style_button(leave_button, "ghost")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.text = "FFA · %d–%d players · sends hit all enemy lanes" % [
		NetworkManager.MIN_PLAYERS_TO_START, NetworkManager.MAX_LOBBY_PLAYERS
	]
	name_input.text = GameConfig.get_player_name()
	_build_slot_widgets()
	_refresh_ui()
	NetworkManager.lobby_status_changed.connect(_on_lobby_status_changed)
	NetworkManager.lobby_updated.connect(_refresh_ui)
	NetworkManager.peer_disconnected.connect(func(_id): _refresh_ui())


func _build_slot_widgets() -> void:
	for child in slots_row.get_children():
		child.queue_free()
	_slot_labels.clear()
	_slot_status_labels.clear()
	for i in NetworkManager.MAX_LOBBY_PLAYERS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.text = "Slot %d" % (i + 1)
		UIStyles.style_label(title, "muted")
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.text = "—"
		UIStyles.style_label(name_lbl, "body")
		var status_lbl := Label.new()
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.text = "Empty"
		UIStyles.style_label(status_lbl, "muted")
		box.add_child(title)
		box.add_child(name_lbl)
		box.add_child(status_lbl)
		slots_row.add_child(box)
		_slot_labels.append(name_lbl)
		_slot_status_labels.append(status_lbl)


func _refresh_ui() -> void:
	var slots: Array = NetworkManager.get_lobby_slots()
	for i in range(_slot_labels.size()):
		var entry: Dictionary = slots[i] if i < slots.size() else {}
		if entry.is_empty():
			_slot_labels[i].text = "—"
			_slot_status_labels[i].text = "Empty"
		else:
			_slot_labels[i].text = str(entry.get("name", "Player"))
			_slot_status_labels[i].text = "Ready" if entry.get("ready", false) else "Not ready"
			if int(entry.get("peer_id", 0)) == NetworkManager.get_local_peer_id():
				_slot_status_labels[i].text += " · You"
	var ready := NetworkManager.is_local_ready()
	ready_button.text = "LEAVE QUEUE" if ready else "JOIN QUEUE"
	start_button.visible = NetworkManager.can_press_start()
	start_button.disabled = not NetworkManager.can_start_match()
	if NetworkManager.is_dedicated_server:
		status_label.text = NetworkManager.lobby_status
	elif NetworkManager.is_server():
		status_label.text = NetworkManager.lobby_status
		if NetworkManager.get_lobby_player_count() < NetworkManager.MIN_PLAYERS_TO_START:
			start_button.text = "START MATCH (need %d+)" % NetworkManager.MIN_PLAYERS_TO_START
		elif not NetworkManager.can_start_match():
			start_button.text = "START MATCH (all must join queue)"
		else:
			start_button.text = "START MATCH"
	else:
		if NetworkManager.is_local_ready():
			status_label.text = "In queue — waiting for other players..."
		else:
			status_label.text = "Click JOIN QUEUE when you're ready to play."


func _on_ready_pressed() -> void:
	GameConfig.set_player_name(name_input.text)
	NetworkManager.set_local_ready(not NetworkManager.is_local_ready())
	_refresh_ui()


func _on_start_pressed() -> void:
	GameConfig.set_player_name(name_input.text)
	NetworkManager.request_start_match()


func _on_leave_pressed() -> void:
	NetworkManager.leave_lobby()


func _on_lobby_status_changed(text: String) -> void:
	if not text.is_empty():
		status_label.text = text
	_refresh_ui()
