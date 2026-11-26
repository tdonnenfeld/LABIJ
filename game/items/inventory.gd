extends RefCounted

const Catalog = preload("res://game/items/catalog.gd")
const CAPACITY := 12
var items: Array[String] = ["sword", "shield", "potion"]
var weapon_index := 0
var shield_index := 1
var armor_index := -1
var weapon: String:
	get:
		return items[weapon_index]
var shield: String:
	get:
		return items[shield_index]

func add(id: String) -> bool:
	if items.size() >= CAPACITY or Catalog.get_item(id) == null:
		return false
	items.append(id)
	return true

func equip(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item = Catalog.get_item(items[index])
	if item.kind == "weapon":
		weapon_index = index
	elif item.kind == "shield":
		shield_index = index
	elif item.kind == "armor":
		armor_index = index
	else:
		return false
	return true

func is_equipped(index: int) -> bool:
	return index == weapon_index or index == shield_index or index == armor_index

func remove(index: int) -> String:
	if index < 0 or index >= items.size() or is_equipped(index):
		return ""
	var id := items[index]
	items.remove_at(index)
	if weapon_index > index:
		weapon_index -= 1
	if shield_index > index:
		shield_index -= 1
	if armor_index > index:
		armor_index -= 1
	return id

func state() -> Array:
	return [items.duplicate(), weapon_index, shield_index, armor_index]

func apply(state_data: Array) -> void:
	items.assign(state_data[0])
	weapon_index = state_data[1]
	shield_index = state_data[2]
	armor_index = state_data[3]
