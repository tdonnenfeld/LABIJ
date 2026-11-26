extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var other := World.new()
	root.add_child(other)
	other.build(123, false, 2)
	var ok: bool = world.monsters.size() == other.monsters.size() and world.monsters.size() > 36
	for id in world.monsters:
		ok = ok and world.monsters[id].kind == other.monsters[id].kind and world.monsters[id].node.position == other.monsters[id].node.position
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.inventory.add("scroll_firebolt")
	ok = ok and not actor.use_item(3) and actor.inventory.items.size() == 4
	actor.skills.credit(6, 25)
	ok = ok and not actor.buy_talent("firebolt") and actor.use_item(3) and actor.skills.learned.has("firebolt")
	ok = ok and actor.inventory.items.size() == 3
	actor.inventory.add("scroll_fireball")
	ok = ok and not actor.use_item(3)
	actor.skills.credit(6, 75)
	ok = ok and actor.use_item(3)
	actor.inventory.add("mail")
	ok = ok and actor.use_item(3) and actor.inventory.armor_index == 3
	if not ok:
		push_error("Expedition tests failed")
	quit(0 if ok else 1)
