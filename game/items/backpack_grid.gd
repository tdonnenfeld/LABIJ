extends Control

const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Icons = preload("res://game/items/item_icons.gd")
const CELL := 40
signal selected(index: int)
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
	ready_data = data.size() == 7
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
	var extent := Catalog.dimensions(id)
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
	preview.size = Vector2(Catalog.dimensions(model.items[index])) * CELL
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"index": index, "offset": at - model.positions[index], "split": Input.is_physical_key_pressed(KEY_SHIFT), "revision": model.revision}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not ready_data or not data is Dictionary or not data.has("revision") or data.revision != model.revision:
		return false
	var replica := Inventory.new()
	replica.apply(model.state())
	return replica.move_item(data.index, cell_at(at_position) - data.offset, data.split)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		moved.emit(data.index, cell_at(at_position) - data.offset, data.split, data.revision)

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
		var area := Rect2(Vector2(model.positions[i]) * CELL, Vector2(Catalog.dimensions(id)) * CELL).grow(-2)
		var active := i == chosen or i == hovered
		draw_rect(area, Color("#88704a") if active else Color("#66523b"))
		draw_rect(area, Color("#efcf85") if active else Color("#b39962"), false, 2.0)
		var icon_size := minf(area.size.x, area.size.y) - 5.0
		var icon_area := Rect2(area.get_center() - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		draw_texture_rect(Icons.texture(id), icon_area, false)
		if model.quantities[i] > 1:
			var text := str(model.quantities[i])
			draw_string_outline(font, area.end - Vector2(23, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("#261c15"))
			draw_string(font, area.end - Vector2(23, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#fff0c9"))
