extends Control

## Main menu — solo, host lobby, or join server queue.

@onready var panel: PanelContainer = $Panel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var address_input: LineEdit = $Panel/Margin/VBox/JoinSection/AddressRow/AddressInput
@onready var solo_button: Button = $Panel/Margin/VBox/SoloButton
@onready var host_button: Button = $Panel/Margin/VBox/HostSection/HostButton
@onready var join_button: Button = $Panel/Margin/VBox/JoinSection/JoinButton
@onready var update_button: Button = $Panel/Margin/VBox/UpdateButton
@onready var quit_button: Button = $Panel/Margin/VBox/QuitButton


func _ready() -> void:
	UIStyles.apply_panel(panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.55)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	$Panel/Margin/VBox/TitleLabel.text = "MAZE WARS"
	UIStyles.style_label($Panel/Margin/VBox/SubtitleLabel, "muted")
	$Panel/Margin/VBox/SubtitleLabel.text = "Tower defense lane wars"
	UIStyles.style_label($Panel/Margin/VBox/HostSection/HostLabel, "muted")
	UIStyles.style_label($Panel/Margin/VBox/JoinSection/JoinLabel, "muted")
	UIStyles.style_label(status_label, "muted")
	UIStyles.style_label($Panel/Margin/VBox/VersionLabel, "muted")
	$Panel/Margin/VBox/VersionLabel.add_theme_font_size_override("font_size", 11)
	UIStyles.style_label($Panel/Margin/VBox/JoinSection/AddressRow/AddressLabel, "muted")
	UIStyles.style_button(solo_button, "accent")
	UIStyles.style_button(host_button, "secondary")
	UIStyles.style_button(join_button, "accent")
	UIStyles.style_button(update_button, "gold")
	UIStyles.style_button(quit_button, "ghost")
	update_button.visible = false
	update_button.text = "UPDATE AVAILABLE"
	address_input.text = GameConfig.get_last_server_address()
	address_input.placeholder_text = "e.g. 192.168.1.42"
	status_label.text = "Solo vs AI, or join a 2-4 player queue (v%s)" % GameVersion.version_label
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/VersionLabel.text = "v%s" % GameVersion.version_label
	NetworkManager.lobby_status_changed.connect(_on_lobby_status_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	GameConfig.load_settings()
	address_input.text = GameConfig.get_last_server_address()
	UpdateChecker.update_available.connect(_on_update_available)
	UpdateChecker.check_for_updates()


func _on_solo_pressed() -> void:
	NetworkManager.start_solo()


func _on_host_pressed() -> void:
	_set_multiplayer_busy(true)
	var err := NetworkManager.host_game()
	if err != OK:
		_set_multiplayer_busy(false)
		return
	NetworkManager.enter_lobby()


func _on_join_pressed() -> void:
	var address := address_input.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the server IP, then click Join Queue."
		return
	_set_multiplayer_busy(true)
	var err := NetworkManager.join_game(address)
	if err != OK:
		_set_multiplayer_busy(false)


func _on_connected_to_server() -> void:
	status_label.text = "Connected. Loading queue..."


func _set_multiplayer_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy
	solo_button.disabled = busy
	address_input.editable = not busy


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_update_pressed() -> void:
	status_label.text = "Closing game to download update..."
	update_button.disabled = true
	if not UpdateChecker.launch_updater():
		status_label.text = "Could not find updater. Use Play-MazeWars.bat or itch.io."
		update_button.disabled = false


func _on_update_available(_remote_label: String) -> void:
	update_button.visible = true
	status_label.text = "New build available — click Update to download"


func _on_lobby_status_changed(text: String) -> void:
	if not text.is_empty():
		status_label.text = text


func _on_connection_failed() -> void:
	_set_multiplayer_busy(false)
