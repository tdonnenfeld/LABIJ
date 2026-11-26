extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> bool:
	if not condition:
		push_error(label)
	return condition

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	var partner := Player.new()
	root.add_child(partner)
	partner.setup(false, false)
	var party := {1: actor, 2: partner}
	var count: int = world.monsters.size()
	actor.floor_id = 3
	actor.position = world.branch_entries[6] + Vector3.UP
	var ok := check(not world.transfer(actor, 1), "Gate must be locked")
	for enemy in world.monsters.values():
		if enemy.boss and enemy.floor != 6:
			enemy.health = 0
			world.reward_kill(enemy, actor, party)
			world.reward_kill(enemy, actor, party)
	ok = check(world.objective.runes.size() == 2 and world.objective.gate_open(), "Two distinct shared runes") and ok
	ok = check(world.transfer(actor, 1) and actor.floor_id == 6, "Gate opens") and ok
	actor.position = world.objective.jewel_position + Vector3.UP
	ok = check(not world.interact_objective(actor, 1), "Sentinel guards Jewel") and ok
	for enemy in world.monsters.values():
		if enemy.boss and enemy.floor == 6:
			enemy.health = 0
			world.reward_kill(enemy, actor, party)
	ok = check(world.interact_objective(actor, 1) and world.objective.carrier == 1, "Claim Jewel") and ok
	var hunters := 0
	var hunter: Dictionary
	for enemy in world.monsters.values():
		if enemy.reserve:
			hunters += 1
			hunter = enemy
			ok = check(enemy.health > 0, "Reserve activated") and ok
	ok = check(hunters == 4 and world.monsters.size() == count, "Finite population") and ok
	hunter.health = 0
	world.reward_kill(hunter, actor, party)
	partner.floor_id = actor.floor_id
	partner.position = actor.position
	world.release_jewel(actor, 1)
	world.update_objective(party, 90)
	ok = check(world.objective.carrier == 0 and world.objective.pressure() == 3, "Handoff and pressure rises") and ok
	ok = check(world.interact_objective(partner, 2) and world.objective.carrier == 2 and hunter.health == 0, "Recovery never respawns hunters") and ok
	ok = check(world.release_jewel(partner, 2) and world.interact_objective(partner, 2), "Voluntary handoff") and ok
	partner.position = world.stair_position(6, false) + Vector3.UP
	ok = check(world.transfer(partner, 2) and partner.floor_id == 3, "Return from sanctuary") and ok
	for floor_id in [3, 2, 1]:
		partner.position = world.stair_position(floor_id, false) + Vector3.UP
		ok = check(world.transfer(partner, 2) and partner.floor_id == floor_id - 1, "Ascend") and ok
	partner.position = world.stair_position(0, false) + Vector3.UP
	ok = check(world.transfer(partner, 2) and world.objective.result == "victory" and world.objective.winner == 2, "Escape wins") and ok
	var copy := World.Objective.new()
	copy.apply(world.objective.state())
	ok = check(copy.state() == world.objective.state(), "Objective replication") and ok
	var defeat := World.Objective.new()
	world.objective = defeat
	partner.health = 0
	world.update_objective(party, 0.1)
	ok = check(defeat.result == "", "One downed companion does not end run") and ok
	for enemy in world.monsters.values():
		enemy.health = 0.0
	actor.floor_id = 0
	actor.position = Vector3(0, 1, 0)
	actor.combat_timer = 0.0
	partner.floor_id = 0
	partner.position = Vector3(1, 1, 0)
	ok = check(world.revive_companion(actor, party) and partner.health > 0, "Safe nearby revive") and ok
	actor.health = 0
	partner.health = 0
	world.update_objective(party, 0.1)
	ok = check(defeat.result == "defeat", "All downed ends expedition") and ok
	quit(0 if ok else 1)
