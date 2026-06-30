extends Control

## Main menu — solo, LAN host/join, or quit.

const MATCH_SCENE := "res://scenes/match/match.tscn"

@onready var panel: PanelContainer = $Panel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var address_row: HBoxContainer = $Panel/Margin/VBox/AddressRow
@onready var address_input: LineEdit = $Panel/Margin/VBox/AddressRow/AddressInput
@onready var solo_button: Button = $Panel/Margin/VBox/SoloButton
@onready var host_button: Button = $Panel/Margin/VBox/HostButton
@onready var join_button: Button = $Panel/Margin/VBox/JoinButton
@onready var update_button: Button = $Panel/Margin/VBox/UpdateButton
@onready var quit_button: Button = $Panel/Margin/VBox/QuitButton


func _ready() -> void:
	UIStyles.apply_panel(panel, true)
	$Dimmer.color = Color(0.02, 0.03, 0.06, 0.55)
	UIStyles.style_label($Panel/Margin/VBox/TitleLabel, "title")
	$Panel/Margin/VBox/TitleLabel.text = "MAZE WARS"
	UIStyles.style_label($Panel/Margin/VBox/SubtitleLabel, "muted")
	$Panel/Margin/VBox/SubtitleLabel.text = "Tower defense lane wars"
	UIStyles.style_label(status_label, "muted")
	UIStyles.style_label($Panel/Margin/VBox/VersionLabel, "muted")
	$Panel/Margin/VBox/VersionLabel.add_theme_font_size_override("font_size", 11)
	UIStyles.style_label($Panel/Margin/VBox/AddressRow/AddressLabel, "muted")
	UIStyles.style_button(solo_button, "accent")
	UIStyles.style_button(host_button, "secondary")
	UIStyles.style_button(join_button, "secondary")
	UIStyles.style_button(update_button, "gold")
	UIStyles.style_button(quit_button, "ghost")
	update_button.visible = false
	update_button.text = "UPDATE AVAILABLE"
	address_input.text = _default_lan_address()
	address_input.placeholder_text = "Host IP address"
	status_label.text = "Solo vs AI, or 2-player LAN"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/Margin/VBox/VersionLabel.text = "v%s" % GameVersion.version_label
	NetworkManager.lobby_status_changed.connect(_on_lobby_status_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	GameConfig.load_settings()
	UpdateChecker.update_available.connect(_on_update_available)
	UpdateChecker.check_for_updates()


func _default_lan_address() -> String:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		if addr.contains(".") and not addr.begins_with("127."):
			return addr
	return "127.0.0.1"


func _on_solo_pressed() -> void:
	NetworkManager.start_solo()


func _on_host_pressed() -> void:
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true
	var err := NetworkManager.host_game()
	if err != OK:
		host_button.disabled = false
		join_button.disabled = false
		solo_button.disabled = false


func _on_join_pressed() -> void:
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true
	var err := NetworkManager.join_game(address_input.text.strip_edges())
	if err != OK:
		host_button.disabled = false
		join_button.disabled = false
		solo_button.disabled = false


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
	status_label.text = text


func _on_connection_failed() -> void:
	host_button.disabled = false
	join_button.disabled = false
	solo_button.disabled = false
