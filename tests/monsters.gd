extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Bestiary = preload("res://game/monsters/bestiary.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(42069, false)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	var ok := world.monsters.size() == 16 and Bestiary.stats("brute")[1] > Bestiary.stats("rat")[1]
	actor.skills.credit(1, 200)
	ok = ok and actor.buy_talent("sword") and actor.buy_talent("quick") and actor.buy_talent("keen")
	var mob: Dictionary = world.monsters[0]
	world.hit_monster(actor, mob, {1: actor})
	ok = ok and mob.health == 0 and world.loot.drops.size() == 1
	var guardian: Dictionary = world.monsters[20 + 3]
	world.hit_monster(actor, guardian, {1: actor})
	ok = ok and guardian.health > 0 and guardian.bleed == 4.0 and guardian.bleed_owner == 1
	var before: float = guardian.health
	world.simulate({}, 1.0)
	ok = ok and guardian.health < before
	if not ok:
		push_error("Monster and talent effects test failed")
	quit(0 if ok else 1)
