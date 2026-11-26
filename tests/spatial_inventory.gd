extends SceneTree

const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Player = preload("res://game/player.gd")
const Loot = preload("res://game/items/loot.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var bag := Inventory.new()
	check(bag.used_cells() == 1 and bag.positions[0] == Inventory.WORN, "Worn gear outside grid")
	check(bag.add("potion", 4) and bag.count("potion") == 5 and bag.items.size() == 3, "Stack merges on pickup")
	check(bag.add("potion") and bag.items.size() == 4 and bag.used_cells() == 2, "Overflow makes new stack")
	check(bag.move_item(2, Vector2i(4, 0), true) and bag.count("potion") == 6, "Split conserves count")
	check(bag.move_item(4, bag.positions[3]) and bag.count("potion") == 6, "Merge conserves count")
	check(bag.add("axe"), "Large item pickup")
	var axe := bag.items.find("axe")
	check(not bag.move_item(axe, Vector2i(7, 4)), "Reject out-of-bounds placement")
	check(not bag.move_item(axe, bag.positions[2]), "Reject overlapping placement")
	check(bag.move_item(axe, Vector2i(5, 1)), "Valid large item move")
	check(bag.equip(axe) and bag.positions[axe] == Inventory.WORN and bag.positions[0] != Inventory.WORN, "Equipment replacement returns old gear to grid")
	var replica := Inventory.new()
	replica.apply(bag.state())
	check(replica.state() == bag.state(), "Placement and stack snapshot roundtrip")
	var full := Inventory.new()
	while full.add("scroll_firebolt"):
		pass
	check(full.used_cells() == Inventory.CAPACITY, "Grid fills without weight or slot limit")
	var before := full.state()
	check(not full.add("mail") and full.state() == before, "Full pickup atomic")
	check(not full.add("potion", 5) and full.state() == before, "Partial stack merge rolls back if no space")
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	check(player.configure_profile("Scout", 0, 2) and player.inventory.count("arrows") == 24, "Starting ammunition")
	var loot := Loot.new()
	root.add_child(loot)
	loot.spawn("arrows", 0, Vector3.ZERO, 12)
	check(loot.pickup(player) and player.inventory.count("arrows") == 36, "Loot stack quantity")
	var index := player.inventory.items.find("arrows")
	check(player.inventory.remove(index) == "arrows" and player.inventory.count("arrows") == 35, "Single use consumes one")
	check(player.inventory.remove_stack(index) == "arrows" and not player.begin_attack(), "Empty quiver prevents attack")
	quit(0 if failures == 0 else 1)
