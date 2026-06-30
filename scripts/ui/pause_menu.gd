extends Control

## In-match pause menu: settings, forfeit, and exit.

signal resumed
signal forfeit_requested
signal main_menu_requested

enum View { MAIN, SETTINGS, FORFEIT_CONFIRM }

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var main_view: VBoxContainer = $Panel/Margin/VBox/MainView
@onready var settings_view: VBoxContainer = $Panel/Margin/VBox/SettingsView
@onready var forfeit_view: VBoxContainer = $Panel/Margin/VBox/ForfeitView
@onready var resume_button: Button = $Panel/Margin/VBox/MainView/ResumeButton
@onready var settings_button: Button = $Panel/Margin/VBox/MainView/SettingsButton
@onready var forfeit_button: Button = $Panel/Margin/VBox/MainView/ForfeitButton
@onready var main_menu_button: Button = $Panel/Margin/VBox/MainView/MainMenuButton
@onready var settings_back_button: Button = $Panel/Margin/VBox/SettingsView/SettingsBackButton
@onready var master_volume_slider: HSlider = $Panel/Margin/VBox/SettingsView/MasterVolumeRow/MasterVolumeSlider
@onready var master_volume_value: Label = $Panel/Margin/VBox/SettingsView/MasterVolumeRow/MasterVolumeValue
@onready var forfeit_confirm_button: Button = $Panel/Margin/VBox/ForfeitView/ForfeitConfirmButton
@onready var forfeit_cancel_button: Button = $Panel/Margin/VBox/ForfeitView/ForfeitCancelButton

var _open := false
var _view: View = View.MAIN


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	UIStyles.apply_panel(panel, true)
	dimmer.color = Color(0.02, 0.03, 0.06, 0.72)
	UIStyles.style_label(title_label, "title")
	title_label.text = "PAUSED"
	UIStyles.style_button(resume_button, "accent")
	UIStyles.style_button(settings_button, "secondary")
	UIStyles.style_button(forfeit_button, "danger")
	UIStyles.style_button(main_menu_button, "secondary")
	UIStyles.style_button(settings_back_button, "secondary")
	UIStyles.style_button(forfeit_confirm_button, "danger")
	UIStyles.style_button(forfeit_cancel_button, "ghost")
	UIStyles.style_label($Panel/Margin/VBox/SettingsView/SettingsTitle, "muted")
	UIStyles.style_label($Panel/Margin/VBox/SettingsView/MasterVolumeRow/MasterVolumeLabel, "muted")
	UIStyles.style_label(master_volume_value, "chip_stat")
	UIStyles.style_label($Panel/Margin/VBox/ForfeitView/ForfeitPrompt, "warning")
	$Panel/Margin/VBox/ForfeitView/ForfeitPrompt.text = "Forfeit this match? You will lose."
	master_volume_slider.min_value = 0.0
	master_volume_slider.max_value = 100.0
	master_volume_slider.step = 1.0
	master_volume_slider.value = GameConfig.master_volume * 100.0
	_update_volume_label()
	_show_view(View.MAIN)


func is_open() -> bool:
	return _open


func show_menu() -> void:
	_open = true
	visible = true
	_show_view(View.MAIN)
	get_tree().paused = true
	get_viewport().set_input_as_handled()


func hide_menu() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_show_view(View.MAIN)
	get_tree().paused = false
	resumed.emit()


func _show_view(view: View) -> void:
	_view = view
	main_view.visible = view == View.MAIN
	settings_view.visible = view == View.SETTINGS
	forfeit_view.visible = view == View.FORFEIT_CONFIRM
	match view:
		View.MAIN:
			title_label.text = "PAUSED"
		View.SETTINGS:
			title_label.text = "SETTINGS"
		View.FORFEIT_CONFIRM:
			title_label.text = "FORFEIT"


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match _view:
		View.MAIN:
			hide_menu()
		View.SETTINGS, View.FORFEIT_CONFIRM:
			_show_view(View.MAIN)


func _on_resume_pressed() -> void:
	hide_menu()


func _on_settings_pressed() -> void:
	_show_view(View.SETTINGS)


func _on_forfeit_pressed() -> void:
	_show_view(View.FORFEIT_CONFIRM)


func _on_main_menu_pressed() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	main_menu_requested.emit()


func _on_settings_back_pressed() -> void:
	GameConfig.save_settings()
	_show_view(View.MAIN)


func _on_master_volume_changed(value: float) -> void:
	GameConfig.set_master_volume(value / 100.0)
	_update_volume_label()


func _update_volume_label() -> void:
	master_volume_value.text = "%d%%" % int(round(master_volume_slider.value))


func _on_forfeit_confirm_pressed() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	forfeit_requested.emit()


func _on_forfeit_cancel_pressed() -> void:
	_show_view(View.MAIN)
