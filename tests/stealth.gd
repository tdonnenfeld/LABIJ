extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Exploration = preload("res://game/world/exploration.gd")
const Catalog = preload("res://game/items/catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var map := Exploration.new()
	var tiles := {Vector2i.ZERO: true, Vector2i(1, 0): true, Vector2i(2, 0): true, Vector2i(2, 1): true, Vector2i(2, 2): true}
	map.reveal(0, tiles, Vector3.ZERO)
	check(map.explored[0].has(Vector2i(2, 0)) and not map.explored[0].has(Vector2i(2, 2)), "Map must reveal only visible tiles")
	map.reveal(0, tiles, Vector3(6, 0, 0))
	check(map.explored[0].has(Vector2i(2, 2)) and map.explored[0].has(Vector2i.ZERO), "Exploration persists")
	map.reveal(1, tiles, Vector3(6, 0, 6))
	check(map.explored[0] != map.explored[1], "Separate floor memory")
	var world := World.new()
	root.add_child(world)
	world.build(123, false)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.skills.credit(11, 200)
	check(actor.buy_talent("soft_step") and actor.buy_talent("ambush") and actor.buy_talent("deep_cut"), "Stealth tree")
	var mob: Dictionary = world.monsters[0]
	mob.kind = "goblin"
	mob.health = 100.0
	mob.asleep = true
	world.hit_monster(actor, mob, {1: actor})
	check(is_equal_approx(mob.health, 62.5) and mob.bleed_damage == 3.0, "Ambush damage and bleed")
	var before: float = mob.health
	world.hit_monster(actor, mob, {1: actor})
	check(is_equal_approx(before - mob.health, 25.0), "Threat prevents repeated ambush")
	check(Catalog.noise_multiplier("mail") > Catalog.noise_multiplier("leather"), "Heavy armour is louder")
	actor.inventory.add("noise_stone")
	check(world.throw_distraction(actor, 3, 1) and not actor.inventory.items.has("noise_stone"), "Throw consumes stone")
	check(world.projectiles.shots.size() == 1 and world.projectiles.shots.values()[0].effect == "distraction", "Distraction projectile")
	var other: Dictionary = world.monsters[1]
	other.asleep = true
	world.distraction_lands(world.projectiles.shots.values()[0], other.node.position)
	check(not other.asleep and other.investigate > 0 and other.threat.is_empty(), "Noise stone distracts without aggro")
	quit(0 if failures == 0 else 1)
