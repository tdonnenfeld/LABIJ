extends RefCounted

const Catalog = preload("res://game/items/catalog.gd")
const WIDTH := 8
const HEIGHT := 5
const CAPACITY := WIDTH * HEIGHT
const WORN := Vector2i(-1, -1)
var items: Array[String] = []
var positions: Array[Vector2i] = []
var quantities: Array[int] = []
var revision := 0
var weapon_index := 0
var shield_index := 1
var armor_index := -1
var weapon: String:
	get:
		return items[weapon_index]
var shield: String:
	get:
		return items[shield_index]

func _init() -> void:
	reset_items(["sword", "shield", "potion"])

func reset_items(initial: Array) -> void:
	items.assign(initial)
	positions.clear()
	quantities.clear()
	weapon_index = 0
	shield_index = 1
	armor_index = -1
	for i in range(items.size()):
		positions.append(WORN)
		quantities.append(1)
	for i in range(2, items.size()):
		positions[i] = first_fit(items[i], i)
	revision += 1

func is_equipped(index: int) -> bool:
	return index >= 0 and index in [weapon_index, shield_index, armor_index]

func quantity(index: int) -> int:
	return quantities[index] if index >= 0 and index < quantities.size() else 0

func count(id: String) -> int:
	var total := 0
	for i in range(items.size()):
		if items[i] == id:
			total += quantities[i]
	return total

func used_cells() -> int:
	var total := 0
	for i in range(items.size()):
		if not is_equipped(i):
			var extent := Catalog.dimensions(items[i])
			total += extent.x * extent.y
	return total

func item_at(cell: Vector2i, ignore: int = -1) -> int:
	for i in range(items.size()):
		if i == ignore or positions[i] == WORN:
			continue
		if Rect2i(positions[i], Catalog.dimensions(items[i])).has_point(cell):
			return i
	return -1

func fits(id: String, at: Vector2i, ignore: int = -1) -> bool:
	var extent := Catalog.dimensions(id)
	if at.x < 0 or at.y < 0 or at.x + extent.x > WIDTH or at.y + extent.y > HEIGHT:
		return false
	for y in range(at.y, at.y + extent.y):
		for x in range(at.x, at.x + extent.x):
			if item_at(Vector2i(x, y), ignore) >= 0:
				return false
	return true

func first_fit(id: String, ignore: int = -1) -> Vector2i:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var at := Vector2i(x, y)
			if fits(id, at, ignore):
				return at
	return WORN

func add(id: String, amount: int = 1) -> bool:
	if Catalog.get_item(id) == null or amount <= 0 or amount > Catalog.stack_limit(id):
		return false
	var before := state()
	var remaining := amount
	var limit := Catalog.stack_limit(id)
	for i in range(items.size()):
		if items[i] == id and not is_equipped(i) and quantities[i] < limit:
			var transfer := mini(remaining, limit - quantities[i])
			quantities[i] += transfer
			remaining -= transfer
			if remaining == 0:
				break
	if remaining > 0:
		var at := first_fit(id)
		if at == WORN:
			apply(before)
			return false
		items.append(id)
		positions.append(at)
		quantities.append(remaining)
	revision += 1
	return true

func equip(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	if is_equipped(index):
		return true
	var kind: String = Catalog.get_item(items[index]).kind
	var previous := -1
	match kind:
		"weapon": previous = weapon_index
		"shield": previous = shield_index
		"armor": previous = armor_index
		_: return false
	var source := positions[index]
	positions[index] = WORN
	if previous >= 0:
		var at := source if fits(items[previous], source) else first_fit(items[previous])
		if at == WORN:
			positions[index] = source
			return false
		positions[previous] = at
	match kind:
		"weapon": weapon_index = index
		"shield": shield_index = index
		"armor": armor_index = index
	revision += 1
	return true

func move_item(index: int, at: Vector2i, split: bool = false) -> bool:
	if index < 0 or index >= items.size() or is_equipped(index):
		return false
	if at.x < 0 or at.y < 0 or at.x >= WIDTH or at.y >= HEIGHT:
		return false
	var id := items[index]
	var other := item_at(at, index)
	if split:
		if quantities[index] < 2 or not fits(id, at):
			return false
		var amount := quantities[index] / 2
		quantities[index] -= amount
		items.append(id)
		positions.append(at)
		quantities.append(amount)
	elif other >= 0 and items[other] == id and Catalog.stack_limit(id) > 1:
		var amount := mini(quantities[index], Catalog.stack_limit(id) - quantities[other])
		if amount <= 0:
			return false
		quantities[other] += amount
		quantities[index] -= amount
		if quantities[index] == 0:
			erase_entry(index)
	else:
		if at == positions[index] or not fits(id, at, index):
			return false
		positions[index] = at
	revision += 1
	return true

func consume(id: String) -> bool:
	for i in range(items.size()):
		if items[i] == id and not is_equipped(i):
			return remove(i) != ""
	return false

func erase_entry(index: int) -> void:
	items.remove_at(index)
	positions.remove_at(index)
	quantities.remove_at(index)
	if weapon_index > index:
		weapon_index -= 1
	if shield_index > index:
		shield_index -= 1
	if armor_index > index:
		armor_index -= 1

func remove(index: int) -> String:
	if index < 0 or index >= items.size() or is_equipped(index):
		return ""
	var id := items[index]
	quantities[index] -= 1
	if quantities[index] == 0:
		erase_entry(index)
	revision += 1
	return id

func remove_stack(index: int) -> String:
	if index < 0 or index >= items.size() or is_equipped(index):
		return ""
	var id := items[index]
	erase_entry(index)
	revision += 1
	return id

func state() -> Array:
	return [items.duplicate(), weapon_index, shield_index, armor_index, positions.duplicate(), quantities.duplicate(), revision]

func apply(data: Array) -> void:
	items.assign(data[0])
	weapon_index = data[1]
	shield_index = data[2]
	armor_index = data[3]
	positions.assign(data[4])
	quantities.assign(data[5])
	revision = data[6]
