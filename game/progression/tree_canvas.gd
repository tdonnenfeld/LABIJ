extends Control

const Parchment = preload("res://game/ui/parchment.gd")
const NODE_MIN := Vector2(156, 54)
const GAP := Vector2(22, 30)
const MARGIN := Vector2(18, 16)
signal selected(id: String)
var positions: Dictionary = {}
var links: Array = []
var buttons: Dictionary = {}
var node_size := NODE_MIN

func build(model, domain: int, chosen: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	positions.clear()
	links.clear()
	buttons.clear()
	node_size = NODE_MIN
	var rows: Dictionary = {}
	var max_depth := 0
	var max_row := 1
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
		max_depth = maxi(max_depth, depth)
		max_row = maxi(max_row, rows[depth].size())
		var id: String = node[0]
		var button := Button.new()
		button.text = "%s\n%s" % [node[2], "Learned" if model.learned.has(id) else ("Scroll · %d XP" % node[3] if model.SCROLL_REQUIREMENTS.has(id) else "%d XP" % node[3])]
		button.tooltip_text = node[7]
		button.add_theme_font_size_override("font_size", 13)
		var fill := Color("#49362b")
		var edge := Color("#94784b")
		if model.learned.has(id):
			fill = Color("#3f5038")
			edge = Color("#97a870")
		elif model.can_buy(id):
			fill = Color("#695033")
			edge = Color("#dbc285")
		else:
			fill = Color("#50483e")
		if chosen == id:
			edge = Color("#f4df9c")
		var normal := Parchment.frame(fill, edge, 6.0)
		normal.set_border_width_all(2 if chosen == id else 1)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", Parchment.frame(fill.lightened(0.12), Color("#f4df9c"), 6.0))
		button.add_theme_stylebox_override("pressed", normal)
		add_child(button)
		buttons[id] = button
		button.pressed.connect(func(): selected.emit(id))
		var minimum := button.get_combined_minimum_size()
		node_size.x = maxf(node_size.x, minimum.x)
		node_size.y = maxf(node_size.y, minimum.y)
		if node[4] != "":
			links.append([node[4], id, model.learned.has(node[4])])
	var width := maxf(560.0, max_row * node_size.x + (max_row - 1) * GAP.x + 2.0 * MARGIN.x)
	var height := (max_depth + 1) * node_size.y + max_depth * GAP.y + 2.0 * MARGIN.y
	custom_minimum_size = Vector2(width, height)
	for depth in range(max_depth + 1):
		var group: Array = rows.get(depth, [])
		if depth > 0:
			group.sort_custom(func(a: Array, b: Array):
				var left: Vector2 = positions.get(a[4], Vector2.ZERO)
				var right: Vector2 = positions.get(b[4], Vector2.ZERO)
				return left.x < right.x if left.x != right.x else str(a[0]) < str(b[0]))
		var row_width := group.size() * node_size.x + maxi(0, group.size() - 1) * GAP.x
		var left := (width - row_width) * 0.5
		for i in range(group.size()):
			var id: String = group[i][0]
			var at := Vector2(left + i * (node_size.x + GAP.x), MARGIN.y + depth * (node_size.y + GAP.y))
			var button: Button = buttons[id]
			button.position = at
			button.size = node_size
			positions[id] = at + node_size * 0.5
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#c4ad83"))
	for link in links:
		if positions.has(link[0]) and positions.has(link[1]):
			var start: Vector2 = positions[link[0]] + Vector2(0, node_size.y * 0.5)
			var finish: Vector2 = positions[link[1]] - Vector2(0, node_size.y * 0.5)
			var middle := (start.y + finish.y) * 0.5
			var color := Color("#6b633a") if link[2] else Color("#8a775b")
			draw_polyline(PackedVector2Array([start, Vector2(start.x, middle), Vector2(finish.x, middle), finish]), color, 2.0, true)
