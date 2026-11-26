extends SceneTree

const Catalog = preload("res://game/items/catalog.gd")
const Icons = preload("res://game/items/item_icons.gd")
const Satchel = preload("res://game/items/inventory_ui.gd")
const Inventory = preload("res://game/items/inventory.gd")
var failures := 0
var actions: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	for id in Catalog.ITEMS:
		var texture := Icons.texture(id)
		check(texture != Icons.FALLBACK and texture.get_size() == Vector2(64, 64), "Catalog icon: " + id)
	check(Icons.texture("sword:keen") == Icons.texture("sword"), "Affix uses base icon")
	check(Icons.texture("jewel") != Icons.FALLBACK and Icons.texture("missing") == Icons.FALLBACK, "Objective and fallback")
	var satchel := Satchel.new()
	root.add_child(satchel)
	satchel.action.connect(func(index: int, drop: bool): actions.append([index, drop]))
	var inventory := Inventory.new()
	inventory.add("axe")
	inventory.add("scroll_firebolt")
	inventory.add("noise_stone")
	inventory.add("mail")
	inventory.add("sword:keen")
	satchel.refresh(inventory.state())
	check(satchel.grid.model.used_cells() == inventory.used_cells() and satchel.selection == 0, "Spatial grid and initial selection")
	check(satchel.use_button.text == "Unequip" and satchel.drop_button.disabled, "Equipped protected")
	satchel.send(true)
	check(actions.is_empty(), "Cannot request dropping equipped gear")
	satchel.select_item(2)
	check(satchel.use_button.text == "Drink potion", "Potion action")
	satchel.send(false)
	check(actions == [[2, false]], "Exact inventory index emitted")
	satchel.select_item(4)
	check(satchel.use_button.text == "Read scroll" and "mastery" in satchel.details.text, "Scroll requirements")
	satchel.select_item(5)
	check(satchel.use_button.text == "Throw stone", "Distraction action")
	satchel.select_item(7)
	check("UNCOMMON" in satchel.item_kind.text and satchel.item_title.text == Catalog.get_item("sword:keen").title and satchel.item_picture.texture == Icons.texture("sword"), "Affix presentation")
	inventory.equip(6)
	satchel.refresh(inventory.state())
	satchel.equipment.select_equipment(2)
	check(satchel.selection == 6 and satchel.drop_button.disabled, "Equipment card selects exact slot")
	inventory.remove(2)
	satchel.refresh(inventory.state())
	check(satchel.selection == 5 and satchel.item_title.text == Catalog.get_item("mail").title, "Selection follows shifted item")
	check(satchel.grid.model.items.size() == 7 and satchel.grid.model.positions[5] == Inventory.WORN, "No extra entries and worn gear outside grid")
	satchel.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
