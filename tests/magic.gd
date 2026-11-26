extends SceneTree

const Player = preload("res://game/player.gd")
const Projectiles = preload("res://game/combat/projectiles.gd")
const World = preload("res://game/world.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	player.direction = Vector2(0, -1)
	player.wants_sprint = true
	player.update_sprint(1.0)
	var ok: bool = player.sprinting and player.stamina == 78.0
	player.advance_combat(0.5)
	ok = ok and player.stamina == 78.0
	player.wants_block = true
	player.update_sprint(1.0)
	ok = ok and not player.sprinting
	player.wants_block = false
	player.skills.credit(6, 100)
	ok = ok and player.buy_talent("firebolt") and player.skills.assign_slot(0, "firebolt")
	ok = ok and player.activate(0) and player.mana == 85.0
	ok = ok and player.advance_cast(0.2) == "" and player.advance_cast(0.3) == "firebolt"
	ok = ok and not player.activate(0)
	ok = ok and Projectiles.segment_hit(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 0), 1.0) >= 0
	ok = ok and Projectiles.segment_hit(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 3, 0), 1.0) < 0
	var world := World.new()
	root.add_child(world)
	world.build(42069, false)
	var mob: Dictionary = world.monsters[2]
	world.apply_spell_damage({"owner": 1, "damage": 15.0, "effect": "burn", "domain": 6, "bonus": 0.0}, mob, {1: player})
	ok = ok and mob.burn == 4.0 and mob.health == 35.0
	world.apply_spell_damage({"owner": 1, "damage": 10.0, "effect": "slow", "domain": 7, "bonus": 0.0}, mob, {1: player})
	ok = ok and mob.burn == 0.0 and mob.slow == 4.0 and mob.health == 22.5
	if not ok:
		push_error("Magic and sprint tests failed")
	quit(0 if ok else 1)
