extends RefCounted

const Catalog = preload("res://game/items/catalog.gd")
const WIDTH := 8
const HEIGHT := 5
const CAPACITY := WIDTH * HEIGHT
const WORN := Vector2i(-1, -1)
const BELT_CAPACITY := 4
const SLOT_KINDS := ["weapon", "shield", "armor", "helmet", "gloves", "boots", "amulet", "ring", "ring"]
var accessories: Array[int] = [-1, -1, -1, -1, -1, -1]
var items: Array[String] = []
var positions: Array[Vector2i] = []
var quantities: Array[int] = []
var rotated: Array[bool] = []
var belt := 0
var revision := 0
var weapon_index := 0
var shield_index := 1
var armor_index := -1
var weapon: String:
	get:
		return items[weapon_index] if weapon_index >= 0 else "unarmed"
var shield: String:
	get:
		return items[shield_index] if shield_index >= 0 else "empty_shield"

func _init() -> void:
	reset_items(["sword", "shield", "potion"])

func reset_items(initial: Array) -> void:
	items.assign(initial)
	positions.clear()
	quantities.clear()
	rotated.clear()
	belt = 0
	weapon_index = 0
	shield_index = 1
	armor_index = -1
	accessories.assign([-1, -1, -1, -1, -1, -1])
	for i in range(items.size()):
		positions.append(WORN)
		quantities.append(1)
		rotated.append(false)
	for i in range(2, items.size()):
		positions[i] = first_fit(items[i], i)
	revision += 1

func is_equipped(index: int) -> bool:
	return index >= 0 and (index in [weapon_index, shield_index, armor_index] or index in accessories)

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
			var extent := footprint(items[i], rotated[i])
			total += extent.x * extent.y
	return total

func item_at(cell: Vector2i, ignore: int = -1) -> int:
	for i in range(items.size()):
		if i == ignore or positions[i] == WORN:
			continue
		if Rect2i(positions[i], footprint(items[i], rotated[i])).has_point(cell):
			return i
	return -1

static func footprint(id: String, turned: bool = false) -> Vector2i:
	var extent := Catalog.dimensions(id)
	return Vector2i(extent.y, extent.x) if turned else extent

func fits(id: String, at: Vector2i, ignore: int = -1, turned: bool = false) -> bool:
	var extent := footprint(id, turned)
	if at.x < 0 or at.y < 0 or at.x + extent.x > WIDTH or at.y + extent.y > HEIGHT:
		return false
	for y in range(at.y, at.y + extent.y):
		for x in range(at.x, at.x + extent.x):
			if item_at(Vector2i(x, y), ignore) >= 0:
				return false
	return true

func first_fit(id: String, ignore: int = -1, turned: bool = false) -> Vector2i:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var at := Vector2i(x, y)
			if fits(id, at, ignore, turned):
				return at
	return WORN

func add(id: String, amount: int = 1) -> bool:
	if id in ["unarmed", "empty_shield"] or Catalog.get_item(id) == null or amount <= 0 or amount > Catalog.stack_limit(id):
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
		rotated.append(false)
	revision += 1
	return true

func slot_index(slot: int) -> int:
	match slot:
		0: return weapon_index
		1: return shield_index
		2: return armor_index
		_: return accessories[slot - 3] if slot >= 3 and slot < SLOT_KINDS.size() else -1

func set_slot(slot: int, index: int) -> void:
	match slot:
		0: weapon_index = index
		1: shield_index = index
		2: armor_index = index
		_: accessories[slot - 3] = index

func equipped_slot(index: int) -> int:
	if index < 0:
		return -1
	for slot in range(SLOT_KINDS.size()):
		if slot_index(slot) == index:
			return slot
	return -1

func equip(index: int, slot: int = -1) -> bool:
	if index < 0 or index >= items.size():
		return false
	var kind: String = Catalog.get_item(items[index]).kind
	if slot == -1:
		slot = SLOT_KINDS.find(kind)
		if kind == "ring" and slot_index(7) >= 0 and slot_index(8) < 0:
			slot = 8
	if slot < 0 or slot >= SLOT_KINDS.size() or SLOT_KINDS[slot] != kind:
		return false
	if is_equipped(index):
		return equipped_slot(index) == slot
	var previous := slot_index(slot)
	var source := positions[index]
	positions[index] = WORN
	if previous >= 0:
		var at := source if fits(items[previous], source, -1, rotated[previous]) else first_fit(items[previous], -1, rotated[previous])
		if at == WORN:
			at = first_fit(items[previous], -1, not rotated[previous])
			if at != WORN:
				rotated[previous] = not rotated[previous]
		if at == WORN:
			positions[index] = source
			return false
		positions[previous] = at
	set_slot(slot, index)
	revision += 1
	return true

func unequip(index: int, at: Vector2i = WORN) -> bool:
	var slot := equipped_slot(index)
	if slot < 0:
		return false
	var turned := rotated[index]
	if at == WORN:
		at = first_fit(items[index], index, turned)
		if at == WORN:
			at = first_fit(items[index], index, not turned)
			turned = not turned
	if at == WORN or not fits(items[index], at, index, turned):
		return false
	positions[index] = at
	rotated[index] = turned
	set_slot(slot, -1)
	revision += 1
	return true

func move_item(index: int, at: Vector2i, split: bool = false) -> bool:
	if index < 0 or index >= items.size():
		return false
	if at.x < 0 or at.y < 0 or at.x >= WIDTH or at.y >= HEIGHT:
		return false
	if is_equipped(index):
		return not split and unequip(index, at)
	var id := items[index]
	var other := item_at(at, index)
	if split:
		if quantities[index] < 2 or not fits(id, at, -1, rotated[index]):
			return false
		var amount := floori(float(quantities[index]) / 2.0)
		quantities[index] -= amount
		items.append(id)
		positions.append(at)
		quantities.append(amount)
		rotated.append(rotated[index])
	elif other >= 0 and items[other] == id and Catalog.stack_limit(id) > 1:
		var amount := mini(quantities[index], Catalog.stack_limit(id) - quantities[other])
		if amount <= 0:
			return false
		quantities[other] += amount
		quantities[index] -= amount
		if quantities[index] == 0:
			erase_entry(index)
	else:
		if at == positions[index] or not fits(id, at, index, rotated[index]):
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
	rotated.remove_at(index)
	if weapon_index > index:
		weapon_index -= 1
	if shield_index > index:
		shield_index -= 1
	if armor_index > index:
		armor_index -= 1
	for i in range(accessories.size()):
		if accessories[i] > index:
			accessories[i] -= 1

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
	return [items.duplicate(), weapon_index, shield_index, armor_index, positions.duplicate(), quantities.duplicate(), revision, rotated.duplicate(), belt, accessories.duplicate()]

func apply(data: Array) -> void:
	items.assign(data[0])
	weapon_index = data[1]
	shield_index = data[2]
	armor_index = data[3]
	positions.assign(data[4])
	quantities.assign(data[5])
	revision = data[6]
	rotated.assign(data[7])
	belt = data[8]
	accessories.assign(data[9])

func rotate_item(index: int) -> bool:
	if index < 0 or index >= items.size() or is_equipped(index):
		return false
	var id := items[index]
	var extent := Catalog.dimensions(id)
	if extent.x == extent.y:
		return false
	var turned := not rotated[index]
	if not fits(id, positions[index], index, turned):
		return false
	rotated[index] = turned
	revision += 1
	return true

func sort_items() -> bool:
	var before := state()
	var i := 0
	while i < items.size():
		if not is_equipped(i) and Catalog.stack_limit(items[i]) > 1:
			var j := i + 1
			while j < items.size():
				if not is_equipped(j) and items[j] == items[i]:
					var transfer := mini(Catalog.stack_limit(items[i]) - quantities[i], quantities[j])
					quantities[i] += transfer
					quantities[j] -= transfer
					if quantities[j] == 0:
						erase_entry(j)
						continue
				j += 1
		i += 1
	var order: Array[int] = []
	for index in range(items.size()):
		if not is_equipped(index):
			order.append(index)
			positions[index] = WORN
	order.sort_custom(func(a: int, b: int):
		var sa := Catalog.dimensions(items[a])
		var sb := Catalog.dimensions(items[b])
		var area_a := sa.x * sa.y
		var area_b := sb.x * sb.y
		if area_a != area_b:
			return area_a > area_b
		if items[a] != items[b]:
			return items[a] < items[b]
		return a < b)
	for index in order:
		var at := first_fit(items[index], index)
		rotated[index] = false
		if at == WORN:
			at = first_fit(items[index], index, true)
			rotated[index] = true
		if at == WORN:
			apply(before)
			return false
		positions[index] = at
	if state() == before:
		return false
	revision += 1
	return true

func load_belt(index: int) -> bool:
	if belt >= BELT_CAPACITY or index < 0 or index >= items.size() or items[index] != "potion":
		return false
	if remove(index) == "":
		return false
	belt += 1
	return true

func unload_belt() -> bool:
	if belt <= 0 or not add("potion"):
		return false
	belt -= 1
	return true

func consume_belt(slot: int) -> bool:
	if slot < 0 or slot >= belt:
		return false
	belt -= 1
	revision += 1
	return true
