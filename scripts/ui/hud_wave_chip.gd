class_name HudWaveChip
extends RefCounted

## Builds compact wave timeline inside the top-bar wave chip.


const MWWaveTimelineScript := preload("res://scripts/ui/components/mw_wave_timeline.gd")


static func ensure_timeline(
	wave_chip: PanelContainer,
	wave_preview_label: Label,
	existing: MWWaveTimeline
) -> MWWaveTimeline:
	if existing and is_instance_valid(existing):
		return existing

	var hbox: HBoxContainer = wave_chip.get_node_or_null("WaveContentHBox") as HBoxContainer
	if hbox:
		var slot: VBoxContainer = hbox.get_node_or_null("WaveTimelineSlot") as VBoxContainer
		if slot and slot.get_child_count() > 0:
			return slot.get_child(0) as MWWaveTimeline

	var wave_vbox: VBoxContainer = wave_chip.get_node("WaveVBox")
	hbox = HBoxContainer.new()
	hbox.name = "WaveContentHBox"
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	wave_chip.remove_child(wave_vbox)
	hbox.add_child(wave_vbox)

	var timeline_slot := VBoxContainer.new()
	timeline_slot.name = "WaveTimelineSlot"
	timeline_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timeline_slot.size_flags_horizontal = Control.SIZE_SHRINK_END

	var timeline: MWWaveTimeline = MWWaveTimelineScript.new()
	timeline.set_compact(true)
	timeline_slot.add_child(timeline)
	hbox.add_child(timeline_slot)

	wave_chip.add_child(hbox)
	wave_chip.custom_minimum_size = Vector2(300, 52)
	wave_preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wave_preview_label.clip_text = true
	wave_preview_label.custom_minimum_size.x = 118
	return timeline
