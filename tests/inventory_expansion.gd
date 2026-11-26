extends SceneTree

const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Player = preload("res://game/player.gd")
const Trade = preload("res://game/items/trade.gd")
const Models = preload("res://game/items/loot_models.gd")
const Loot = preload("res://game/items/loot.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func actor() -> Node3D:
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	return player

func run() -> void:
	var bag := Inventory.new()
	bag.add("spear")
	var spear := bag.items.find("spear")
	check(bag.rotate_item(spear) and bag.rotated[spear] and Inventory.footprint("spear", true) == Vector2i(4, 1), "Rotation changes footprint")
	check(bag.move_item(spear, Vector2i(4, 4)), "Rotated item can move to bottom row")
	var before := bag.state()
	check(not bag.rotate_item(spear) and bag.state() == before, "Blocked rotation atomic")
	bag.add("potion", 4)
	bag.move_item(2, Vector2i(2, 2), true)
	var potion_count := bag.count("potion")
	check(bag.sort_items() and bag.count("potion") == potion_count and bag.items.size() == 4, "Sorting merges stacks and conserves items")
	check(bag.load_belt(bag.items.find("potion")) and bag.belt == 1 and bag.count("potion") == potion_count - 1, "Load belt consumes backpack dose")
	check(bag.unload_belt() and bag.belt == 0 and bag.count("potion") == potion_count, "Unload restores backpack dose")
	var a = actor()
	var b = actor()
	a.position = Vector3.ZERO
	b.position = Vector3.RIGHT
	a.display_name = "A"
	b.display_name = "B"
	a.inventory.add("potion", 4)
	for i in range(4):
		check(a.inventory.load_belt(a.inventory.items.find("potion")), "Load belt dose")
	check(a.inventory.belt == 4 and not a.inventory.load_belt(a.inventory.items.find("potion")), "Belt cap")
	check(not a.drink_belt(0), "No wasted potion at full HP")
	a.health = 50
	check(a.drink_belt(3) and a.health == 85 and a.inventory.belt == 3, "Belt heals once")
	check(not a.drink_belt(3), "Invalid empty belt slot")
	a.inventory.add("axe")
	b.inventory.add("arrows", 12)
	var actors := {1: a, 2: b}
	var trade := Trade.new()
	check(trade.invite(1, 2, actors), "Invite nearby companion")
	var v := trade.view(2, actors)
	check(v.incoming and trade.operate(2, "join", -1, v.id, v.version, v.revision, actors), "Accept invitation")
	v = trade.view(1, actors)
	check(not trade.operate(1, "offer", 0, v.id, v.version, v.revision, actors), "Reject equipped offer")
	check(trade.operate(1, "offer", a.inventory.items.find("axe"), v.id, v.version, v.revision, actors), "Offer axe")
	v = trade.view(2, actors)
	check(trade.operate(2, "offer", b.inventory.items.find("arrows"), v.id, v.version, v.revision, actors), "Offer arrows")
	v = trade.view(1, actors)
	check(trade.operate(1, "confirm", -1, v.id, v.version, v.revision, actors) and a.inventory.count("axe") == 1, "One confirmation does not transfer")
	v = trade.view(2, actors)
	check(trade.operate(2, "confirm", -1, v.id, v.version, v.revision, actors), "Two confirmations commit")
	check(a.inventory.count("arrows") == 12 and b.inventory.count("axe") == 1 and a.inventory.count("axe") == 0 and b.inventory.count("arrows") == 0, "Exchange conserves both items")
	check(trade.invite(1, 2, actors), "New invitation")
	a.inventory.add("noise_stone")
	trade.sweep(actors, 0.0)
	check(trade.sessions.is_empty(), "Inventory change cancels trade")
	check(trade.invite(1, 2, actors), "Invite again")
	b.position = Vector3(10, 0, 0)
	trade.sweep(actors, 0.0)
	check(trade.sessions.is_empty(), "Distance cancels trade")
	var full := Inventory.new()
	while full.add("scroll_firebolt"):
		pass
	var sender := Inventory.new()
	sender.add("axe")
	var original := sender.state()
	var full_state := full.state()
	check(not trade.transact(sender, full, sender.items.find("axe"), -1) and sender.state() == original and full.state() == full_state, "Failed trade atomic")
	var loot := Loot.new()
	root.add_child(loot)
	loot.visual = true
	for id in Catalog.ITEMS:
		loot.spawn(id, 0, Vector3.ZERO)
		var node: Node3D = loot.drops[loot.next_id - 1].node
		var model := node.get_node_or_null("ItemModel")
		check(model != null and model.get_child_count() > 0, "Ground model " + id)
		for part in model.get_children():
			check(part is MeshInstance3D and part.mesh != null, "Non-colliding visual " + id)
	loot.visual = false
	loot.spawn("axe", 0, Vector3.ZERO)
	check(loot.drops[loot.next_id - 1].node.get_child_count() == 0, "Headless drop has no model")
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.trade_panel != null and main.potion_belt.slots.size() == 4, "Trade and belt UI created")
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
