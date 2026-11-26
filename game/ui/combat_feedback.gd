extends Node3D

const COLORS := {"damage": Color("#f5da80"), "magic": Color("#f1a4ff"), "incoming": Color("#ff7770"), "blocked": Color("#a7d7ff"), "heal": Color("#91ed90"), "xp": Color("#c3b4ff"), "status": Color("#f6f2df")}
var texts: Array = []
var viewed_floor := 0
var local_layer: Control
var screen_count := 0

func show_event(event: Dictionary, local_id: int) -> void:
	if event.floating == "" or event.floor != viewed_floor:
		return
	var color: Color = COLORS.get(event.style, Color.WHITE)
	if event.target == local_id and local_layer:
		var screen_label := Label.new()
		screen_label.text = event.floating
		screen_label.add_theme_font_size_override("font_size", 25)
		screen_label.add_theme_color_override("font_color", color)
		screen_label.add_theme_color_override("font_outline_color", Color.BLACK)
		screen_label.add_theme_constant_override("outline_size", 5)
		screen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		local_layer.add_child(screen_label)
		screen_label.position = local_layer.size * Vector2(0.60, 0.49) + Vector2(0, float(screen_count % 4) * 25)
		screen_count += 1
		var tween := screen_label.create_tween().set_parallel(true)
		tween.tween_property(screen_label, "position:y", screen_label.position.y - 65, 1.1)
		tween.tween_property(screen_label, "modulate:a", 0.0, 0.45).set_delay(0.65)
		screen_label.set_meta("feedback_tween", tween)
		tween.chain().tween_callback(func():
			screen_label.remove_meta("feedback_tween")
			screen_label.queue_free())
		return
	if texts.size() >= 64:
		var old: Dictionary = texts.pop_front()
		old.node.queue_free()
	var label := Label3D.new()
	label.text = event.floating
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.outline_size = 9
	label.pixel_size = 0.008
	label.modulate = color
	add_child(label)
	label.position = event.position + Vector3(float(int(event.id) % 3 - 1) * 0.18, 0.2, 0)
	texts.append({"node": label, "floor": event.floor, "age": 0.0})

func _process(delta: float) -> void:
	for i in range(texts.size() - 1, -1, -1):
		var entry: Dictionary = texts[i]
		entry.age += delta
		entry.node.position.y += delta * 0.65
		entry.node.visible = entry.floor == viewed_floor
		entry.node.modulate.a = clampf((1.35 - entry.age) / 0.5, 0.0, 1.0)
		if entry.age >= 1.35:
			entry.node.queue_free()
			texts.remove_at(i)

func reset() -> void:
	for entry in texts:
		entry.node.queue_free()
	texts.clear()
	if local_layer:
		for child in local_layer.get_children():
			if child.has_meta("feedback_tween"):
				var tween: Tween = child.get_meta("feedback_tween")
				tween.kill()
				child.remove_meta("feedback_tween")
			child.queue_free()
	screen_count = 0
