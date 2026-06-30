extends Control

## In-match HUD: economy, waves, towers, sends.

signal tower_build_requested(tower_id: String)
signal upgrade_requested
signal sell_requested
signal undo_requested
signal send_requested(package_id: String)

const TOWER_IDS: Array[String] = ["arrow", "cannon", "frost", "magic"]
const HOTKEY_SLOTS := 8
const MWTowerCardButtonScript := preload("res://scripts/ui/components/mw_tower_card_button.gd")
const MWEnemySendButtonScript := preload("res://scripts/ui/components/mw_enemy_send_button.gd")
const MWSectionLabelScript := preload("res://scripts/ui/components/mw_section_label.gd")
const MW := preload("res://theme/maze_wars_colors.gd")

@onready var gold_label: Label = $TopBar/TopMargin/TopRow/LeftStats/GoldChip/GoldVBox/GoldLabel
@onready var income_label: Label = $TopBar/TopMargin/TopRow/LeftStats/IncomeChip/IncomeVBox/IncomeLabel
@onready var income_timer_label: Label = $TopBar/TopMargin/TopRow/LeftStats/TimerChip/TimerVBox/IncomeTimerLabel
@onready var send_timer_label: Label = $TopBar/TopMargin/TopRow/RightStats/SendChip/SendVBox/SendTimerLabel
@onready var wave_label: Label = $TopBar/TopMargin/TopRow/WaveChip/WaveVBox/WaveLabel
@onready var wave_preview_label: Label = $TopBar/TopMargin/TopRow/WaveChip/WaveVBox/WavePreviewLabel
@onready var wave_chip: PanelContainer = $TopBar/TopMargin/TopRow/WaveChip
@onready var core_health_bar: ProgressBar = $TopBar/TopMargin/TopRow/RightStats/CoreChip/CoreVBox/CoreHealthBar
@onready var core_label: Label = $TopBar/TopMargin/TopRow/RightStats/CoreChip/CoreVBox/CoreLabel
@onready var message_toast: PanelContainer = $MessageToast
@onready var message_label: Label = $MessageToast/MessageLabel
@onready var tower_info_panel: PanelContainer = $TowerInfoPanel
@onready var tower_info_label: RichTextLabel = $TowerInfoPanel/InfoMargin/InfoVBox/TowerInfoLabel
@onready var upgrade_button: Button = $TowerInfoPanel/InfoMargin/InfoVBox/ActionRow/UpgradeButton
@onready var sell_button: Button = $TowerInfoPanel/InfoMargin/InfoVBox/ActionRow/SellButton
@onready var build_tower_button: Button = $BuildTowerButton
@onready var creeps_button: Button = $CreepsButton
@onready var tower_picker_panel: PanelContainer = $TowerPickerPanel
@onready var creep_picker_panel: PanelContainer = $CreepPickerPanel
@onready var build_hint_label: Label = $BuildHintLabel
@onready var build_buttons: HBoxContainer = $TowerPickerPanel/PickerMargin/PickerVBox/BuildBar
@onready var send_buttons: HBoxContainer = $CreepPickerPanel/PickerMargin/PickerVBox/SendButtons
@onready var send_queue_label: Label = $CreepPickerPanel/PickerMargin/PickerVBox/SendQueueLabel
@onready var selection_overlay = $SelectionBoxOverlay

var _selected_tower_id: String = ""
var _tower_buttons: Dictionary = {}
var _send_buttons: Dictionary = {}
var _current_gold: int = 0
var _current_income: int = 0
var _current_wave: int = 1
var _send_package_ids: Array[String] = []
var _wave_timeline: MWWaveTimeline
var _tower_picker_open := false
var _creep_picker_open := false


func _ready() -> void:
	theme = UIStyles.get_theme()
	tower_info_panel.visible = false
	tower_picker_panel.visible = false
	creep_picker_panel.visible = false
	message_toast.visible = false
	_apply_theme()
	_cache_send_package_ids()
	_setup_build_buttons()
	_setup_send_buttons()
	_update_tower_selection_visuals()
	update_send_queue([])
	build_tower_button.pressed.connect(_on_build_tower_button_pressed)
	creeps_button.pressed.connect(_on_creeps_button_pressed)
	upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	sell_button.pressed.connect(func(): sell_requested.emit())
	resized.connect(_on_bottom_layout_changed)
	await get_tree().process_frame
	_on_bottom_layout_changed()
	build_tower_button.resized.connect(_on_bottom_layout_changed)
	creeps_button.resized.connect(_on_bottom_layout_changed)
	tower_picker_panel.resized.connect(_on_bottom_layout_changed)
	creep_picker_panel.resized.connect(_on_bottom_layout_changed)
	_disable_ui_focus()


func _on_bottom_layout_changed() -> void:
	HudBottomLayout.layout_bottom_ui(
		size,
		creeps_button,
		build_tower_button,
		creep_picker_panel,
		tower_picker_panel,
		build_hint_label
	)
	_position_tower_info_panel()


func _picker_bottom_y() -> float:
	return HudBottomLayout.picker_bottom_y(size)


func show_build_hint(text: String) -> void:
	if text.is_empty():
		hide_build_hint()
		return
	build_hint_label.text = text.to_upper()
	build_hint_label.add_theme_color_override("font_color", BrandColors.UI_DANGER)
	build_hint_label.visible = true
	call_deferred("_on_bottom_layout_changed")


func hide_build_hint() -> void:
	build_hint_label.visible = false
	build_hint_label.text = ""
	call_deferred("_on_bottom_layout_changed")


func _disable_ui_focus() -> void:
	_set_focus_none_recursive(self)


func _set_focus_none_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_focus_none_recursive(child)


func _apply_theme() -> void:
	UIStyles.apply_panel($TowerInfoPanel, true)
	UIStyles.apply_panel(tower_picker_panel, true)
	UIStyles.apply_panel(creep_picker_panel, true)
	message_toast.add_theme_stylebox_override("panel", UIStyles.make_toast_panel("info"))

	UIStyles.apply_chip($TopBar/TopMargin/TopRow/LeftStats/GoldChip, BrandColors.METALLIC_GOLD)
	UIStyles.apply_chip($TopBar/TopMargin/TopRow/LeftStats/IncomeChip, BrandColors.NEON_CYAN)
	UIStyles.apply_chip($TopBar/TopMargin/TopRow/LeftStats/TimerChip, BrandColors.ELECTRIC_TEAL)
	UIStyles.apply_chip($TopBar/TopMargin/TopRow/RightStats/SendChip, BrandColors.ELECTRIC_TEAL)
	UIStyles.apply_chip($TopBar/TopMargin/TopRow/RightStats/CoreChip, BrandColors.CRIMSON_RED)
	UIStyles.apply_chip(wave_chip, BrandColors.ELECTRIC_TEAL)

	UIStyles.style_label($TopBar/TopMargin/TopRow/LeftStats/GoldChip/GoldVBox/GoldTitle, "chip_title")
	UIStyles.style_label($TopBar/TopMargin/TopRow/LeftStats/IncomeChip/IncomeVBox/IncomeTitle, "chip_title")
	UIStyles.style_label($TopBar/TopMargin/TopRow/LeftStats/TimerChip/TimerVBox/TimerTitle, "chip_title")
	UIStyles.style_label($TopBar/TopMargin/TopRow/RightStats/SendChip/SendVBox/SendTitle, "chip_title")
	UIStyles.style_label(gold_label, "stat_value_gold")
	UIStyles.style_label(income_label, "stat_value_cyan")
	UIStyles.style_label(income_timer_label, "chip_stat")
	UIStyles.style_label(send_timer_label, "chip_stat")
	UIStyles.style_label(wave_label, "stat_value_cyan")
	UIStyles.style_label(wave_preview_label, "muted")
	UIStyles.style_label(core_label, "chip_title")
	core_label.text = "CORE INTEGRITY"
	UIStyles.style_label(send_queue_label, "muted")
	send_queue_label.add_theme_font_size_override("font_size", 10)
	UIStyles.style_label(build_hint_label, "warning")
	build_hint_label.add_theme_font_size_override("font_size", 15)
	build_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.style_label(message_label, "stat")

	UIStyles.style_button(build_tower_button, "accent")
	UIStyles.style_button(creeps_button, "secondary")
	UIStyles.style_button(upgrade_button, "gold")
	UIStyles.style_button(sell_button, "danger")

	_setup_figma_panels()
	_add_picker_section_labels()
	build_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	send_buttons.alignment = BoxContainer.ALIGNMENT_CENTER

	if core_health_bar.has_method("set_health"):
		core_health_bar.set_health(int(core_health_bar.value), int(core_health_bar.max_value))
	else:
		core_health_bar.add_theme_stylebox_override("background", UIStyles.make_progress_bg())
		core_health_bar.add_theme_stylebox_override("fill", UIStyles.make_progress_fill(BrandColors.NEON_CYAN))


func _add_picker_section_labels() -> void:
	var tower_vbox: VBoxContainer = $TowerPickerPanel/PickerMargin/PickerVBox
	if tower_vbox.get_node_or_null("TowerSectionLabel") == null:
		var tower_section := MWSectionLabelScript.new()
		tower_section.name = "TowerSectionLabel"
		tower_section.setup("Build Towers")
		tower_vbox.add_child(tower_section)
		tower_vbox.move_child(tower_section, 0)

	var creep_vbox: VBoxContainer = $CreepPickerPanel/PickerMargin/PickerVBox
	if creep_vbox.get_node_or_null("SendSectionLabel") == null:
		var send_section := MWSectionLabelScript.new()
		send_section.name = "SendSectionLabel"
		send_section.setup("Enemy Sends")
		creep_vbox.add_child(send_section)
		creep_vbox.move_child(send_section, 0)


func _setup_figma_panels() -> void:
	_wave_timeline = HudWaveChip.ensure_timeline(wave_chip, wave_preview_label, _wave_timeline)


func _on_build_tower_button_pressed() -> void:
	_set_tower_picker_open(not _tower_picker_open)


func _on_creeps_button_pressed() -> void:
	_set_creep_picker_open(not _creep_picker_open)


func _set_tower_picker_open(open: bool) -> void:
	_tower_picker_open = open
	tower_picker_panel.visible = open
	_update_action_button_labels()
	call_deferred("_on_bottom_layout_changed")


func _set_creep_picker_open(open: bool) -> void:
	_creep_picker_open = open
	creep_picker_panel.visible = open
	_update_action_button_labels()
	call_deferred("_on_bottom_layout_changed")


func _close_tower_picker_only() -> void:
	_tower_picker_open = false
	tower_picker_panel.visible = false


func _close_creep_picker_only() -> void:
	_creep_picker_open = false
	creep_picker_panel.visible = false


func _close_all_pickers() -> void:
	_close_tower_picker_only()
	_close_creep_picker_only()
	_update_action_button_labels()
	call_deferred("_on_bottom_layout_changed")


func close_pickers_if_open() -> bool:
	if not _tower_picker_open and not _creep_picker_open:
		return false
	_close_all_pickers()
	return true


func _update_action_button_labels() -> void:
	if _selected_tower_id.is_empty():
		build_tower_button.text = "BUILD TOWER" if not _tower_picker_open else "CLOSE"
	else:
		var def: Dictionary = BalanceConfig.get_tower_def(_selected_tower_id)
		var name_text := str(def.get("display_name", _selected_tower_id)).replace(" Tower", "").to_upper()
		build_tower_button.text = name_text if not _tower_picker_open else "CLOSE"
	creeps_button.text = "CLOSE" if _creep_picker_open else "CREEPS"


func _position_tower_info_panel() -> void:
	HudBottomLayout.position_tower_info_panel(
		size,
		tower_info_panel,
		tower_picker_panel,
		_tower_picker_open,
		_picker_bottom_y()
	)


func _cache_send_package_ids() -> void:
	_send_package_ids.clear()
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		_send_package_ids.append(str(pkg.get("id", "")))


func _setup_build_buttons() -> void:
	for i in TOWER_IDS.size():
		var tower_id: String = TOWER_IDS[i]
		var def: Dictionary = BalanceConfig.get_tower_def(tower_id)
		var card: PanelContainer = MWTowerCardButtonScript.new()
		card.setup(tower_id, def, i + 1)
		card.pressed.connect(_on_tower_card_pressed)
		build_buttons.add_child(card)
		_tower_buttons[tower_id] = card


func _setup_send_buttons() -> void:
	var slot := 1
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		var card: PanelContainer = MWEnemySendButtonScript.new()
		card.setup(pkg, slot)
		card.pressed.connect(_on_send_card_pressed)
		send_buttons.add_child(card)
		_send_buttons[str(pkg.get("id", ""))] = card
		slot += 1


func _on_tower_card_pressed(tower_id: String) -> void:
	if _selected_tower_id == tower_id:
		_selected_tower_id = ""
		tower_build_requested.emit("")
	else:
		_selected_tower_id = tower_id
		tower_build_requested.emit(tower_id)
	_update_tower_selection_visuals()
	_update_action_button_labels()


func _on_send_card_pressed(package_id: String) -> void:
	send_requested.emit(package_id)


func set_selected_tower(tower_id: String) -> void:
	_selected_tower_id = tower_id
	_update_tower_selection_visuals()
	_update_action_button_labels()


func _update_tower_selection_visuals() -> void:
	for id in _tower_buttons:
		var card = _tower_buttons[id]
		var def: Dictionary = BalanceConfig.get_tower_def(id)
		var cost: int = int(def.get("cost", 0))
		var can_afford := _current_gold >= cost
		if card.has_method("set_affordable"):
			card.set_affordable(can_afford)
		if card.has_method("set_selected"):
			card.set_selected(id == _selected_tower_id)


func _refresh_send_affordability() -> void:
	for pkg_id in _send_buttons:
		var card = _send_buttons[pkg_id]
		var pkg := _find_send_package(pkg_id)
		if pkg.is_empty():
			continue
		var unlocked := _current_wave >= int(pkg.get("unlock_wave", 1))
		var affordable := _current_gold >= int(pkg.get("cost", 0))
		if card.has_method("set_state"):
			card.set_state(unlocked, affordable)


func _find_send_package(package_id: String) -> Dictionary:
	for pkg: Dictionary in BalanceConfig.get_send_package_list():
		if str(pkg.get("id", "")) == package_id:
			return pkg
	return {}


func update_economy(gold: int, income: int) -> void:
	_current_gold = gold
	_current_income = income
	gold_label.text = str(gold)
	income_label.text = "+%d" % income
	_update_tower_selection_visuals()
	_refresh_send_affordability()


func update_income_timer(seconds: float) -> void:
	income_timer_label.text = "%.0fS" % seconds


func update_send_timer(seconds: float) -> void:
	if seconds < 0.0:
		send_timer_label.text = "INSTANT"
	else:
		send_timer_label.text = "%.0fS" % seconds


func show_send_status(target_count: int) -> void:
	send_queue_label.text = "HIT %d LANE(S)" % target_count


func update_wave(number: int, preview_text: String) -> void:
	_current_wave = number
	wave_label.text = "WAVE %d" % number
	wave_preview_label.text = preview_text.to_upper()
	if _wave_timeline:
		_wave_timeline.set_progress(number, BalanceConfig.get_wave_list().size(), preview_text)
	var is_boss := preview_text.to_lower().contains("boss")
	if is_boss:
		UIStyles.apply_chip(wave_chip, BrandColors.EMBER_ORANGE)
		UIStyles.style_label(wave_label, "warning")
		wave_label.add_theme_font_size_override("font_size", 18)
		UIStyles.style_label(wave_preview_label, "warning")
	else:
		UIStyles.apply_chip(wave_chip, BrandColors.ELECTRIC_TEAL)
		UIStyles.style_label(wave_label, "stat_value_cyan")
		UIStyles.style_label(wave_preview_label, "muted")
	_refresh_send_affordability()


func update_core_health(current: int, maximum: int) -> void:
	if core_health_bar.has_method("set_health"):
		core_health_bar.set_health(current, maximum)
	else:
		core_health_bar.max_value = maximum
		core_health_bar.value = current
	if float(current) / float(maximum) if maximum > 0 else 0.0 < 0.35:
		UIStyles.apply_chip($TopBar/TopMargin/TopRow/RightStats/CoreChip, BrandColors.CRIMSON_RED)
	else:
		UIStyles.apply_chip($TopBar/TopMargin/TopRow/RightStats/CoreChip, BrandColors.STEEL_GRAY)


func show_message(text: String, color: Color = Color.WHITE) -> void:
	var toast_type := UIStyles.toast_type_for_message(text, color)
	message_toast.add_theme_stylebox_override("panel", UIStyles.make_toast_panel(toast_type))
	message_label.text = text.to_upper()
	UIStyles.style_label(message_label, "stat")
	var accent := MW.CYAN
	match toast_type:
		"warn", "warning":
			accent = MW.ORANGE
		"success":
			accent = Color("#22c55e")
		"danger":
			accent = MW.RED
	message_label.add_theme_color_override("font_color", accent)
	message_toast.visible = true
	message_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(message_toast, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func():
		message_toast.visible = false
		message_toast.modulate.a = 1.0
		message_label.text = ""
	)


func show_tower_info(info: Dictionary) -> void:
	tower_info_panel.visible = true
	var text := "[color=#%s]%s[/color]  ·  LV %d\n" % [
		BrandColors.NEON_CYAN.to_html(false),
		str(info.get("name", "")).to_upper(),
		info.get("level", 1)
	]
	text += "[color=#%s]DMG[/color] %.0f   [color=#%s]APS[/color] %.2f   [color=#%s]RNG[/color] %.1f\n" % [
		BrandColors.UI_TEXT_MUTED.to_html(false),
		info.get("damage", 0),
		BrandColors.UI_TEXT_MUTED.to_html(false),
		info.get("attack_speed", 0),
		BrandColors.UI_TEXT_MUTED.to_html(false),
		info.get("range", 0)
	]
	text += "[color=#%s]%s[/color]  ·  TARGET %s" % [
		BrandColors.UI_TEXT_MUTED.to_html(false),
		str(info.get("damage_type", "")).to_upper(),
		str(info.get("targeting", "")).to_upper()
	]
	tower_info_label.text = text
	var upg: int = info.get("upgrade_cost", -1)
	_set_upgrade_button_state(upg > 0, "UPGRADE · %d" % upg if upg > 0 else "")
	sell_button.text = "SELL · %d" % info.get("sell_value", 0)
	call_deferred("_on_bottom_layout_changed")


func show_multi_tower_info(towers: Array) -> void:
	if towers.is_empty():
		hide_tower_info()
		return
	if towers.size() == 1 and towers[0].has_method("get_display_info"):
		show_tower_info(towers[0].get_display_info())
		return
	tower_info_panel.visible = true
	var total_sell := 0
	var total_upgrade := 0
	var can_upgrade := false
	for tower in towers:
		if not is_instance_valid(tower) or not tower.has_method("get_display_info"):
			continue
		var info: Dictionary = tower.get_display_info()
		total_sell += int(info.get("sell_value", 0))
		var upg: int = int(info.get("upgrade_cost", -1))
		if upg > 0:
			can_upgrade = true
			total_upgrade += upg
	var text := "[color=#%s]%d TOWERS SELECTED[/color]\n" % [
		BrandColors.NEON_CYAN.to_html(false),
		towers.size()
	]
	text += "[color=#%s]Drag to select more · U upgrade · X sell · Z undo[/color]" % [
		BrandColors.UI_TEXT_MUTED.to_html(false)
	]
	tower_info_label.text = text
	_set_upgrade_button_state(
		can_upgrade,
		"UPGRADE ALL · %d" % total_upgrade if can_upgrade else ""
	)
	sell_button.text = "SELL ALL · %d" % total_sell
	call_deferred("_on_bottom_layout_changed")


func _set_upgrade_button_state(available: bool, label_text: String = "") -> void:
	upgrade_button.visible = true
	upgrade_button.disabled = not available
	upgrade_button.text = label_text
	upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	upgrade_button.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	upgrade_button.modulate = Color.WHITE if available else Color(1.0, 1.0, 1.0, 0.0)


func update_selection_drag(rect: Rect2) -> void:
	if selection_overlay:
		selection_overlay.set_drag_rect(rect, true)


func hide_selection_drag() -> void:
	if selection_overlay:
		selection_overlay.hide_drag()


func hide_tower_info() -> void:
	tower_info_panel.visible = false


func update_send_queue(queue: Array) -> void:
	if queue.is_empty():
		send_queue_label.text = "INSTANT TO ENEMY LANES"
	else:
		var names: PackedStringArray = []
		for pkg: Dictionary in queue:
			names.append(str(pkg.get("display_name", "?")).to_upper())
		send_queue_label.text = "QUEUED: " + ", ".join(names)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade_tower"):
		upgrade_requested.emit()
		return
	if event.is_action_pressed("sell_tower"):
		sell_requested.emit()
		return
	if event.is_action_pressed("undo_sell"):
		undo_requested.emit()
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var slot := _hotkey_slot_from_key(key)
	if slot < 0:
		return
	get_viewport().set_input_as_handled()
	if key.shift_pressed:
		_hotkey_send(slot)
	else:
		_hotkey_build_tower(slot)


func _hotkey_slot_from_key(key: InputEventKey) -> int:
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code >= KEY_1 and code <= KEY_8:
		return code - KEY_1
	if code >= KEY_KP_1 and code <= KEY_KP_8:
		return code - KEY_KP_1
	return -1


func _hotkey_build_tower(slot: int) -> void:
	if slot < 0 or slot >= TOWER_IDS.size() or slot >= HOTKEY_SLOTS:
		return
	_on_tower_card_pressed(TOWER_IDS[slot])


func _hotkey_send(slot: int) -> void:
	if slot < 0 or slot >= _send_package_ids.size() or slot >= HOTKEY_SLOTS:
		return
	_on_send_card_pressed(_send_package_ids[slot])
