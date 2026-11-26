extends SceneTree

const Inventory = preload("res://game/items/inventory.gd")
const Player = preload("res://game/player.gd")
const Satchel = preload("res://game/items/inventory_ui.gd")
const Trade = preload("res://game/items/trade.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var bag := Inventory.new()
	bag.add("spear")
	var ui := Satchel.new()
	root.add_child(ui)
	ui.refresh(bag.state())
	var payload := {"inventory_drag": true, "index": 3, "offset": Vector2i.ZERO, "split": false, "revision": bag.revision}
	var before := bag.state()
	check(ui.grid.placement(Vector2(160, 0), payload).kind == 1, "Valid placement preview")
	check(ui.grid.placement(Vector2(0, 0), payload).kind == 2, "Collision preview")
	check(ui.grid.placement(Vector2(280, 160), payload).kind == 2, "Bounds preview")
	check(ui.equipment.can_equip(payload, 0) and not ui.equipment.can_equip(payload, 1), "Compatible hand preview")
	check(bag.state() == before, "Preview never changes inventory")
	check(bag.unequip(0) and bag.weapon == "unarmed" and bag.unequip(1) and bag.shield == "empty_shield", "Hands can be empty")
	check(bag.equip(3, 0) and bag.weapon == "spear" and not bag.equip(3, 1), "Right hand weapon only")
	check(bag.move_item(3, Vector2i(7, 0)) and bag.weapon == "unarmed", "Drag worn item to pack")
	for id in ["iron_helm", "leather_gloves", "iron_boots", "ward_amulet", "ward_ring", "ward_ring"]:
		check(bag.add(id) and bag.equip(bag.items.size() - 1), "Equip " + id)
	check(bag.accessories.count(-1) == 0 and bag.slot_index(7) != bag.slot_index(8), "Both rings and all accessories equipped")
	check(not Trade.new().valid_offer(bag, bag.slot_index(7)), "Worn accessories cannot trade")
	var replica := Inventory.new()
	replica.apply(bag.state())
	check(replica.state() == bag.state(), "Accessory replication")
	var removed := bag.items.find("potion")
	bag.remove(removed)
	check(bag.items[bag.slot_index(7)] == "ward_ring", "Accessory indices shift correctly")
	var full := Inventory.new()
	while full.add("scroll_firebolt"):
		pass
	var packed := full.state()
	check(not full.unequip(0) and full.state() == packed, "Full backpack prevents unequip")
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.inventory.unequip(0)
	actor.inventory.unequip(1)
	check(actor.attack_damage() == 6.0 and actor.begin_attack(), "Unarmed strike")
	actor.attack_phase = 0
	actor.wants_block = true
	actor.advance_combat(0.01)
	check(not actor.blocking, "Empty hand cannot block")
	actor.inventory.add("ward_amulet")
	actor.inventory.equip(actor.inventory.items.size() - 1)
	actor.take_damage(20.0, actor.position, true)
	check(is_equal_approx(actor.health, 82.0), "Amulet magical mitigation")
	ui.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
