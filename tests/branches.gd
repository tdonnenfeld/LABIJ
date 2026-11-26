extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Threat = preload("res://game/combat/threat.gd")
const Catalog = preload("res://game/items/catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.floor_id = 1
	actor.position = world.branch_entries[4] + Vector3.UP
	var entry: Vector3 = actor.position
	var ok: bool = world.transfer(actor, 1) and actor.floor_id == 4
	ok = ok and world.transfer(actor, 1) and actor.floor_id == 1 and actor.position == entry
	var bosses := 0
	for mob in world.monsters.values():
		if mob.boss and mob.floor != World.Routes.SANCTUARY:
			bosses += 1
			ok = ok and mob.health > float(world.Bestiary.stats(mob.kind)[1])
	ok = ok and bosses == 2
	var population: int = world.monsters.size()
	for enemy in world.monsters.values():
		if not enemy.boss or enemy.floor == World.Routes.SANCTUARY:
			continue
		actor.floor_id = enemy.floor
		enemy.health = 1.0
		world.apply_spell_damage({"owner": 1, "damage": 100.0, "effect": "stone", "domain": 9, "bonus": 0.0}, enemy, {1: actor})
		ok = ok and enemy.health == 0 and enemy.rewarded
		world.reward_kill(enemy, actor, {1: actor})
	ok = ok and world.loot.drops.size() == 2 and world.monsters.size() == population
	var rewards: Array = []
	for drop in world.loot.drops.values():
		rewards.append(drop.item)
	ok = ok and rewards.has("warden_shield") and rewards.has("oracle_staff")
	var target: Dictionary = world.monsters[0]
	target.kind = "guardian"
	target.health = 100.0
	world.apply_spell_damage({"owner": 1, "damage": 20.0, "effect": "burn", "domain": 6, "bonus": 0.0}, target, {1: actor})
	ok = ok and is_equal_approx(target.health, 87.0) and is_equal_approx(target.threat[1], 13.0)
	world.apply_spell_damage({"owner": 1, "damage": 20.0, "effect": "arrow", "domain": 10, "bonus": 0.0}, target, {1: actor})
	ok = ok and is_equal_approx(target.health, 74.0) and is_equal_approx(target.threat[1], 26.0)
	var trap: Dictionary = world.hazards.traps.values()[0]
	actor.floor_id = trap.floor
	actor.position = trap.node.position + Vector3.UP
	world.hazards.step({1: actor}, 0.1)
	ok = ok and trap.phase == 1 and actor.health == 100
	world.hazards.step({1: actor}, 0.7)
	var after := actor.health
	world.hazards.step({1: actor}, 2.0)
	ok = ok and after < 100 and actor.health == after and trap.phase == 2
	var mob := {"target": 1, "threat": {1: 100.0, 2: 10.0}}
	Threat.taunt(mob, 2)
	Threat.add(mob, 1, 100)
	ok = ok and Threat.choose(mob, {1: true, 2: true}, {1: 1, 2: 1}) == 2
	mob.force_timer = 0
	ok = ok and Threat.choose(mob, {1: true, 2: true}, {1: 1, 2: 1}) == 1
	ok = ok and Threat.reduce(mob, 1) and mob.threat[1] == 100.0
	ok = ok and Catalog.get_item("sword:keen").damage == 30 and Catalog.get_item("sword").damage == 25
	ok = ok and actor.skills.weapon_domain("axe:swift") == 2
	if not ok:
		push_error("Branch, hazard or threat test failed")
	quit(0 if ok else 1)
