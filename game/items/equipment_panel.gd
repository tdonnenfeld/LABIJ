extends Control

const Inventory = preload("res://game/items/inventory.gd")
const Icons = preload("res://game/items/item_icons.gd")
const Catalog = preload("res://game/items/catalog.gd")
const BODY = preload("res://art/ui/paper_doll.svg")
const NAMES := ["Right hand", "Left hand", "Chest", "Head", "Gloves", "Boots", "Amulet", "Ring I", "Ring II"]
const RECTS := [Rect2(0, 113, 70, 94), Rect2(182, 113, 70, 94), Rect2(91, 113, 70, 80), Rect2(91, 5, 70, 68), Rect2(0, 215, 70, 60), Rect2(91, 278, 70, 60), Rect2(182, 5, 70, 60), Rect2(0, 5, 70, 60), Rect2(182, 215, 70, 60)]
signal selected(index: int)
signal equipped_item(index: int, slot: int, revision: int)
signal unequipped_item(index: int, revision: int)
var model := Inventory.new()
var ready_data := false
var chosen := -1
var hover_slot := -1
var drop_status := 0

func _ready() -> void:
	custom_minimum_size = Vector2(252, 338)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hover_slot = -1; queue_redraw())

func refresh(data: Array, index: int) -> void:
	ready_data = data.size() == 10
	if ready_data:
		model.apply(data)
	chosen = index
	queue_redraw()

func slot_at(point: Vector2) -> int:
	for i in range(RECTS.size()):
		if RECTS[i].has_point(point):
			return i
	return -1

func select_equipment(slot: int) -> void:
	if ready_data and slot >= 0:
		var index := model.slot_index(slot)
		if index >= 0:
			selected.emit(index)

func _gui_input(event: InputEvent) -> void:
	if not ready_data:
		return
	if event is InputEventMouseMotion:
		hover_slot = slot_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		var slot := slot_at(event.position)
		if slot < 0:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_equipment(slot)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var index := model.slot_index(slot)
			if index >= 0:
				selected.emit(index)
				unequipped_item.emit(index, model.revision)
			accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	var slot := slot_at(at_position)
	if not ready_data or slot < 0:
		return ""
	var index := model.slot_index(slot)
	return NAMES[slot] + " · Empty" if index < 0 else "%s · %s · Right-click to unequip" % [NAMES[slot], Catalog.get_item(model.items[index]).title]

func _get_drag_data(at_position: Vector2) -> Variant:
	var slot := slot_at(at_position)
	if not ready_data or slot < 0:
		return null
	var index := model.slot_index(slot)
	if index < 0:
		return null
	var preview := TextureRect.new()
	preview.texture = Icons.texture(model.items[index])
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(64, 64)
	set_drag_preview(preview)
	return {"inventory_drag": true, "index": index, "offset": Vector2i.ZERO, "split": false, "revision": model.revision}

func can_equip(data: Variant, slot: int) -> bool:
	if not ready_data or slot < 0 or not data is Dictionary or not data.get("inventory_drag", false) or data.get("revision", -1) != model.revision or data.get("split", false):
		return false
	var index: int = data.get("index", -1)
	if index < 0 or index >= model.items.size() or model.is_equipped(index):
		return false
	var replica := Inventory.new()
	replica.apply(model.state())
	return replica.equip(index, slot)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return can_equip(data, slot_at(at_position))

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var slot := slot_at(at_position)
	if can_equip(data, slot):
		equipped_item.emit(data.index, slot, data.revision)

func _process(_delta: float) -> void:
	var next := 0
	var slot := -1
	if is_visible_in_tree() and get_viewport().gui_is_dragging():
		slot = slot_at(get_local_mouse_position())
		if slot >= 0:
			next = 1 if can_equip(get_viewport().gui_get_drag_data(), slot) else 2
	if next != drop_status or (next != 0 and slot != hover_slot):
		drop_status = next
		if next != 0:
			hover_slot = slot
		queue_redraw()

func _draw() -> void:
	draw_texture_rect(BODY, Rect2(55, 30, 142, 289), false)
	var font := ThemeDB.fallback_font
	for slot in range(RECTS.size()):
		var area: Rect2 = RECTS[slot]
		var index := model.slot_index(slot) if ready_data else -1
		var active := index >= 0 and index == chosen
		draw_rect(area, Color("#6b543c") if index >= 0 else Color("#49362be6"))
		var border := Color("#e5c785") if active or slot == hover_slot else Color("#94784b")
		if slot == hover_slot and drop_status != 0:
			border = Color("#81b96b") if drop_status == 1 else Color("#d16860")
		draw_rect(area, border, false, 2.0)
		if index >= 0:
			var icon_size := minf(area.size.x - 8, area.size.y - 19)
			draw_texture_rect(Icons.texture(model.items[index]), Rect2(area.get_center().x - icon_size * 0.5, area.position.y + 2, icon_size, icon_size), false)
		else:
			draw_string(font, area.position + Vector2(0, area.size.y * 0.55), "—", HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 15, Color("#b99d76"))
		draw_string(font, area.position + Vector2(0, area.size.y - 5), NAMES[slot], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 11, Color("#e8d9b6"))
