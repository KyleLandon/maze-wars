extends PanelContainer

## Debug balance controls for testing.

signal add_gold_requested(amount: int)
signal add_income_requested(amount: int)
signal force_wave_requested
signal force_send_requested
signal spawn_creep_requested(creep_id: String)

@onready var gold_spin: SpinBox = $Margin/VBox/GoldSpin
@onready var income_spin: SpinBox = $Margin/VBox/IncomeSpin


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UIStyles.make_dev_panel())
	UIStyles.style_label($Margin/VBox/Title, "muted")
	$Margin/VBox/Title.text = "DEVELOPER TOOLS"
	for child in $Margin/VBox.get_children():
		if child is Button:
			UIStyles.style_button(child, "dev")
		elif child is SpinBox:
			child.add_theme_color_override("font_color", BrandColors.UI_TEXT_MUTED)


func _on_add_gold_pressed() -> void:
	add_gold_requested.emit(int(gold_spin.value))


func _on_add_income_pressed() -> void:
	add_income_requested.emit(int(income_spin.value))


func _on_force_wave_pressed() -> void:
	force_wave_requested.emit()


func _on_force_send_pressed() -> void:
	force_send_requested.emit()


func _on_spawn_grunt_pressed() -> void:
	spawn_creep_requested.emit("grunt")


func _on_spawn_boss_pressed() -> void:
	spawn_creep_requested.emit("boss")


func _on_toggle_pressed() -> void:
	visible = not visible
