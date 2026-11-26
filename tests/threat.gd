extends SceneTree

const Threat = preload("res://game/combat/threat.gd")
const Player = preload("res://game/player.gd")
const World = preload("res://game/world.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mob := {"target": 1, "threat": {}}
	var eligible := {1: true, 2: true}
	Threat.add(mob, 1, 100)
	Threat.add(mob, 2, 109)
	var ok: bool = Threat.choose(mob, eligible, {1: 1, 2: 1}) == 1
	Threat.add(mob, 2, 5)
	ok = ok and Threat.choose(mob, eligible, {1: 1, 2: 1}) == 2
	ok = ok and Threat.choose(mob, eligible, {1: 1, 2: 8}) == 1
	Threat.add(mob, 2, 20)
	ok = ok and Threat.choose(mob, eligible, {1: 1, 2: 8}) == 2
	ok = ok and Threat.choose(mob, {2: true}, {2: 8}) == 2 and not mob.threat.has(1)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.inventory.add("bow")
	ok = ok and actor.use_item(3) and actor.skills.weapon_domain("bow") == 10
	actor.skills.credit(10, 100)
	ok = ok and actor.buy_talent("archery") and actor.attack_damage() > 18.0
	var world := World.new()
	root.add_child(world)
	world.build(123, false)
	world.strike(actor, {1: actor})
	ok = ok and world.projectiles.shots.size() == 1
	if not ok:
		push_error("Threat and ranged tests failed")
	quit(0 if ok else 1)
