extends SceneTree

const Player = preload("res://game/player.gd")
const Loot = preload("res://game/items/loot.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	var loot := Loot.new()
	root.add_child(loot)
	loot.spawn("axe", 1, Vector3.ZERO)
	var ok := not loot.pickup(player)
	loot.spawn("spear", 0, Vector3.ZERO)
	ok = ok and loot.pickup(player)
	ok = ok and not loot.pickup(player)
	ok = ok and player.use_item(3) and player.inventory.weapon == "spear"
	ok = ok and player.inventory.remove(3) == ""
	player.health = 50
	ok = ok and player.use_item(2) and player.health == 85
	ok = ok and player.inventory.items.size() == 3
	ok = ok and player.begin_attack() and player.stamina == 85
	if not ok:
		push_error("Inventory test failed")
	quit(0 if ok else 1)
