extends RefCounted

const Catalog = preload("res://game/items/catalog.gd")
const CAPACITY := 12
var items: Array[String] = ["sword", "shield", "potion"]
var weapon := "sword"
var shield := "shield"

func add(id: String) -> bool:
	if items.size() >= CAPACITY or Catalog.get_item(id) == null:
		return false
	items.append(id)
	return true

func equip(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var id := items[index]
	var item = Catalog.get_item(id)
	if item.kind == "weapon":
		weapon = id
	elif item.kind == "shield":
		shield = id
	else:
		return false
	return true

func remove(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	var id := items[index]
	# Equipped items must remain available.
	if (id == weapon or id == shield) and items.count(id) == 1:
		return ""
	items.remove_at(index)
	return id

func state() -> Array:
	return [items.duplicate(), weapon, shield]

func apply(state_data: Array) -> void:
	items.assign(state_data[0])
	weapon = state_data[1]
	shield = state_data[2]
