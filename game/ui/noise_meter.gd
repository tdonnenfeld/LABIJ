extends Control

const MAX_LEVEL := 20.0
const SEGMENTS := 24
var level := 0.0
var peak := 0.0

func update_levels(current: float, recent_peak: float) -> void:
	level = clampf(current, 0.0, MAX_LEVEL)
	peak = clampf(recent_peak, level, MAX_LEVEL)
	queue_redraw()

func _draw() -> void:
	var width_per_segment := size.x / SEGMENTS
	if width_per_segment <= 0 or size.y <= 0:
		return
	for i in range(SEGMENTS):
		var threshold := float(i) / SEGMENTS
		var color := Color("#77b483") if threshold < 0.30 else (Color("#d2b36a") if threshold < 0.60 else Color("#d87867"))
		var fill := clampf(level / MAX_LEVEL * SEGMENTS - i, 0.0, 1.0)
		var at := Vector2(i * width_per_segment, 0)
		draw_rect(Rect2(at, Vector2(width_per_segment - 1.0, size.y)), color.darkened(0.78))
		if fill > 0:
			draw_rect(Rect2(at, Vector2((width_per_segment - 1.0) * fill, size.y)), color)
	if peak > 0:
		var x := clampf(peak / MAX_LEVEL * size.x - 1.5, 0.0, size.x - 2.0)
		draw_rect(Rect2(x, 0, 2, size.y), Color("#fff2d4"))
