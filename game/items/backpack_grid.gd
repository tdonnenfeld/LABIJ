extends Control

const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Icons = preload("res://game/items/item_icons.gd")
const CELL := 40
signal selected(index: int)
signal quick_equip(index: int, revision: int)
var preview_rect := Rect2i()
var preview_kind := 0
var preview_key: Array = []
signal moved(index: int, at: Vector2i, split: bool, revision: int)
var model := Inventory.new()
var chosen := -1
var ready_data := false
var hovered := -1

func _ready() -> void:
	custom_minimum_size = Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hovered = -1; queue_redraw())

func refresh(data: Array, index: int) -> void:
	ready_data = data.size() == 10
	if ready_data:
		model.apply(data)
	chosen = index
	queue_redraw()

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func _gui_input(event: InputEvent) -> void:
	if not ready_data:
		return
	if event is InputEventMouseMotion:
		hovered = model.item_at(cell_at(event.position))
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var index := model.item_at(cell_at(event.position))
		if index >= 0 and Catalog.get_item(model.items[index]).kind in Inventory.SLOT_KINDS:
			selected.emit(index)
			quick_equip.emit(index, model.revision)
		accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := model.item_at(cell_at(event.position))
		if index >= 0:
			selected.emit(index)
		accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	if not ready_data:
		return ""
	var index := model.item_at(cell_at(at_position))
	if index < 0:
		return ""
	var id := model.items[index]
	var extent := Inventory.footprint(id, model.rotated[index])
	return "%s · %d×%d · ×%d" % [Catalog.get_item(id).title, extent.x, extent.y, model.quantity(index)]

func _get_drag_data(at_position: Vector2) -> Variant:
	if not ready_data:
		return null
	var at := cell_at(at_position)
	var index := model.item_at(at)
	if index < 0:
		return null
	var preview := TextureRect.new()
	preview.texture = Icons.texture(model.items[index])
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(Inventory.footprint(model.items[index], model.rotated[index])) * CELL
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"inventory_drag": true, "index": index, "offset": at - model.positions[index], "split": Input.is_physical_key_pressed(KEY_SHIFT), "revision": model.revision}

func valid_drag(data: Variant) -> bool:
	return ready_data and data is Dictionary and data.get("inventory_drag", false) and data.get("revision", -1) == model.revision and data.get("index", -1) >= 0 and data.index < model.items.size()

func placement(at_position: Vector2, data: Variant) -> Dictionary:
	if not valid_drag(data):
		return {}
	var index: int = data.index
	var at: Vector2i = cell_at(at_position) - data.offset
	var extent := Inventory.footprint(model.items[index], model.rotated[index])
	var replica := Inventory.new()
	replica.apply(model.state())
	var valid := replica.move_item(index, at, data.split)
	var other := model.item_at(at, index)
	var merge: bool = valid and not data.split and not model.is_equipped(index) and other >= 0 and model.items[other] == model.items[index] and Catalog.stack_limit(model.items[index]) > 1
	if merge:
		at = model.positions[other]
		extent = Inventory.footprint(model.items[other], model.rotated[other])
	return {"rect": Rect2i(at, extent), "kind": 3 if merge else (1 if valid else 2)}

func _process(_delta: float) -> void:
	var data: Variant = get_viewport().gui_get_drag_data()
	var point := get_local_mouse_position()
	var key: Array = []
	if is_visible_in_tree() and get_viewport().gui_is_dragging() and Rect2(Vector2.ZERO, Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL).has_point(point) and valid_drag(data):
		key = [cell_at(point), data.index, data.offset, data.split, model.revision]
	if key == preview_key:
		return
	preview_key = key
	var result: Dictionary = placement(point, data) if not key.is_empty() else {}
	preview_rect = result.get("rect", Rect2i())
	preview_kind = result.get("kind", 0)
	queue_redraw()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var result := placement(at_position, data)
	return result.get("kind", 0) in [1, 3]

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		moved.emit(data.index, cell_at(at_position) - data.offset, data.split, data.revision)
	preview_key.clear()
	preview_kind = 0
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for y in range(Inventory.HEIGHT):
		for x in range(Inventory.WIDTH):
			var area := Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL)
			draw_rect(area.grow(-1), Color("#49362b"))
			draw_rect(area.grow(-1), Color("#94784b"), false)
	if not ready_data:
		return
	for i in range(model.items.size()):
		if model.is_equipped(i):
			continue
		var id := model.items[i]
		var area := Rect2(Vector2(model.positions[i]) * CELL, Vector2(Inventory.footprint(id, model.rotated[i])) * CELL).grow(-2)
		var active := i == chosen or i == hovered
		draw_rect(area, Color("#88704a") if active else Color("#66523b"))
		draw_rect(area, Color("#efcf85") if active else Color("#b39962"), false, 2.0)
		var icon_size := minf(area.size.x, area.size.y) - 5.0
		var icon_area := Rect2(area.get_center() - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		if model.rotated[i]:
			draw_set_transform(area.get_center(), PI / 2.0)
			draw_texture_rect(Icons.texture(id), Rect2(-Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(Icons.texture(id), icon_area, false)
		if model.quantities[i] > 1:
			var text := str(model.quantities[i])
			draw_string_outline(font, area.end - Vector2(23, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("#261c15"))
			draw_string(font, area.end - Vector2(23, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#fff0c9"))

	if preview_kind > 0:
		var bounds := Rect2i(Vector2i.ZERO, Vector2i(Inventory.WIDTH, Inventory.HEIGHT))
		var visible_area := preview_rect.intersection(bounds)
		var area := Rect2(Vector2(visible_area.position) * CELL, Vector2(visible_area.size) * CELL).grow(-1)
		var color := Color("#81b96b") if preview_kind == 1 else (Color("#e4c36b") if preview_kind == 3 else Color("#d16860"))
		draw_rect(area, Color(color.r, color.g, color.b, 0.43))
		draw_rect(area, color, false, 2.5)
		if preview_kind == 3:
			draw_string(font, area.position + Vector2(4, 14), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
