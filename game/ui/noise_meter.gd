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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#221a15"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#94784b"), false, 1.0)
	var width_per_segment := (size.x - 4.0) / SEGMENTS
	if width_per_segment <= 0 or size.y <= 0:
		return
	for i in range(SEGMENTS):
		var threshold := float(i) / SEGMENTS
		var color := Color("#8d9b59") if threshold < 0.30 else (Color("#c0a15e") if threshold < 0.60 else Color("#c16c58"))
		var fill := clampf(level / MAX_LEVEL * SEGMENTS - i, 0.0, 1.0)
		var at := Vector2(2.0 + i * width_per_segment, 2.0)
		draw_rect(Rect2(at, Vector2(width_per_segment - 1.0, size.y - 4.0)), color.darkened(0.78))
		if fill > 0:
			draw_rect(Rect2(at, Vector2((width_per_segment - 1.0) * fill, size.y - 4.0)), color)
	if peak > 0:
		var x := clampf(2.0 + peak / MAX_LEVEL * (size.x - 4.0) - 1.5, 2.0, size.x - 4.0)
		draw_rect(Rect2(x, 2, 2, size.y - 4.0), Color("#fff2d4"))
