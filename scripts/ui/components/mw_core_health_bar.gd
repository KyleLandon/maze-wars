class_name MWCoreHealthBar
extends ProgressBar

## Core health bar with threat-state coloring.

func _ready() -> void:
	show_percentage = false
	custom_minimum_size.y = 14
	add_theme_stylebox_override("background", UIStyles.make_progress_bg())
	add_theme_stylebox_override("fill", UIStyles.make_progress_fill(BrandColors.NEON_CYAN))


func set_health(current: int, maximum: int) -> void:
	max_value = maximum
	value = current
	var pct := float(current) / float(maximum) if maximum > 0 else 0.0
	var fill_color := BrandColors.NEON_CYAN
	if pct < 0.35:
		fill_color = BrandColors.CRIMSON_RED
	elif pct < 0.65:
		fill_color = BrandColors.EMBER_ORANGE
	add_theme_stylebox_override("fill", UIStyles.make_progress_fill(fill_color))
