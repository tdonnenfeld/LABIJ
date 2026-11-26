extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Journal = preload("res://game/world/journal.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.display_name = "Player 1"
	world.watch_player(actor, 1)
	var partner := Player.new()
	root.add_child(partner)
	partner.setup(false, false)
	world.watch_player(partner, 2)
	actor.blocking = true
	actor.take_damage(20.0, actor.position + Vector3(0, 0, -2), false, "Goblin")
	var event: Dictionary = world.journal.history.back()
	var ok: bool = event.floating.contains("Blocked") and event.target == 1 and is_equal_approx(actor.health, 96.0)
	actor.gain_xp(100)
	ok = ok and world.journal.history.back().category == "XP"
	var mob: Dictionary = world.monsters[0]
	mob.health = 100
	world.hit_monster(actor, mob, {1: actor, 2: partner})
	ok = ok and world.journal.history.any(func(e): return e.style == "damage")
	actor.blocking = false
	actor.take_damage(999.0, actor.position, false, "Ogre")
	ok = ok and world.objective.result == "defeat" and partner.health == 100.0
	ok = ok and world.journal.history.back().message.contains("Expedition lost")
	var j := Journal.new()
	for i in range(220):
		j.add("Party", str(i))
	ok = ok and j.history.size() == 200 and j.drain().size() == 220 and j.drain().is_empty()
	if not ok:
		push_error("Party defeat or combat journal test failed")
	quit(0 if ok else 1)
