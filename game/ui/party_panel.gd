extends PanelContainer

var rows := VBoxContainer.new()
var previous := ""

func _ready() -> void:
	add_child(rows)

func refresh(actors: Dictionary, local_id: int, world) -> void:
	var data: Array = []
	for id in actors:
		var actor = actors[id]
		var aggro := 0
		for mob in world.monsters.values():
			if mob.health > 0 and mob.target == id and mob.floor == actor.floor_id:
				aggro += 1
		data.append([actor.display_name + (" (you)" if id == local_id else ""), world.Routes.NAMES[actor.floor_id], ceili(actor.health), ceili(actor.max_health()), aggro])
	var signature := str(data)
	if signature == previous:
		return
	previous = signature
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "PARTY — %d/%d" % [actors.size(), world.party_size]
	rows.add_child(title)
	for member in data:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var name_label := Label.new()
		name_label.text = member[0]
		name_label.custom_minimum_size.x = 90
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(98, 15)
		bar.max_value = member[3]
		bar.value = member[2]
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#bd514d") if member[2] < member[3] * 0.35 else Color("#719a68")
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var hp := Label.new()
		hp.text = "%d/%d" % [member[2], member[3]]
		hp.add_theme_font_size_override("font_size", 11)
		bar.add_child(hp)
		hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var location := Label.new()
		location.text = member[1] + ("  !%d" % member[4] if member[4] > 0 else "")
		location.add_theme_font_size_override("font_size", 11)
		row.add_child(location)
