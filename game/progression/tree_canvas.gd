extends Control

signal selected(id: String)
var positions: Dictionary = {}
var links: Array = []

func build(model, domain: int, chosen: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	positions.clear()
	links.clear()
	var rows: Dictionary = {}
	for node in model.Talents.NODES:
		if node[1] != domain or not model.visible(node):
			continue
		var depth := 0
		var parent: String = node[4]
		while parent != "":
			depth += 1
			parent = model.Talents.find(parent)[4]
		if not rows.has(depth):
			rows[depth] = []
		rows[depth].append(node)
	custom_minimum_size = Vector2(600, rows.size() * 78.0 + 12)
	for depth in rows:
		var group: Array = rows[depth]
		for i in range(group.size()):
			var node: Array = group[i]
			var id: String = node[0]
			var center := Vector2((i + 0.5) * 600.0 / group.size(), depth * 78.0 + 35)
			positions[id] = center
			if node[4] != "":
				links.append([node[4], id, model.learned.has(node[4])])
			var button := Button.new()
			button.text = "%s\n%s" % [node[2], "Learned" if model.learned.has(id) else "%d XP" % node[3]]
			button.tooltip_text = node[7]
			button.position = center - Vector2(69, 23)
			button.size = Vector2(138, 46)
			button.modulate = Color("#a5cc97") if model.learned.has(id) else (Color("#d8c486") if model.can_buy(id) else Color("#9b9b9b"))
			if chosen == id:
				button.modulate = Color.WHITE
			add_child(button)
			button.pressed.connect(func(): selected.emit(id))
	queue_redraw()

func _draw() -> void:
	for link in links:
		if positions.has(link[0]) and positions.has(link[1]):
			draw_line(positions[link[0]] + Vector2(0, 23), positions[link[1]] - Vector2(0, 23), Color("#b6a477") if link[2] else Color("#585e58"), 2.0, true)
