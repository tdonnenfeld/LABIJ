extends PanelContainer

var rows := VBoxContainer.new()
var previous := ""

func _ready() -> void:
	add_child(rows)

func refresh(actors: Dictionary, local_id: int, world) -> void:
	var lines: PackedStringArray = []
	for id in actors:
		var actor = actors[id]
		var aggro := 0
		for mob in world.monsters.values():
			if mob.health > 0 and mob.target == id and mob.floor == actor.floor_id:
				aggro += 1
		lines.append("%s%s  |  %s  |  %d/%d HP%s" % [actor.display_name, " (you)" if id == local_id else "", world.Routes.NAMES[actor.floor_id], ceili(actor.health), ceili(actor.max_health()), "  !%d" % aggro if aggro > 0 else ""])
	var signature := "\n".join(lines)
	if signature == previous:
		return
	previous = signature
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "PARTY — %d/%d" % [actors.size(), world.party_size]
	rows.add_child(title)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 12)
		rows.add_child(label)
