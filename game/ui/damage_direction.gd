extends Control

var source := Vector3.INF
var elapsed := 0.0
var bearing := 0.0
var blocked := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()

func hit(from: Vector3, parried: bool) -> void:
	if not from.is_finite():
		return
	source = from
	blocked = parried
	elapsed = 0.7
	show()

func update_direction(at: Vector3, yaw: float, delta: float) -> void:
	if elapsed <= 0.0:
		return
	elapsed = maxf(0.0, elapsed - delta)
	if elapsed == 0.0:
		hide()
		return
	var offset := source - at
	if Vector2(offset.x, offset.z).length_squared() > 0.01:
		bearing = atan2(offset.x, -offset.z) + yaw
	queue_redraw()

func _draw() -> void:
	if elapsed <= 0.0:
		return
	var direction := Vector2(sin(bearing), -cos(bearing))
	var tangent := Vector2(-direction.y, direction.x)
	var center := size * 0.5
	var at := center + direction * minf(size.x, size.y) * 0.23
	var color := Color("#e7c784") if blocked else Color("#d45b48")
	color.a = clampf(elapsed / 0.3, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([at + direction * 13.0, at - direction * 6.0 + tangent * 14.0, at - direction * 6.0 - tangent * 14.0]), color)

func reset() -> void:
	elapsed = 0.0
	hide()
