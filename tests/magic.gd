extends SceneTree

const Combat = preload("res://game/combat.gd")
const Player = preload("res://game/player.gd")
const Projectiles = preload("res://game/combat/projectiles.gd")
const World = preload("res://game/world.gd")
const DungeonAudio = preload("res://game/audio/dungeon_audio.gd")

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
	for id in World.Spells.SPELLS:
		ok = ok and DungeonAudio.SPELL_VOICES.has(id) and DungeonAudio.SPELL_VOICES[id].get_length() > 0.1
	player.advance_combat(0.5)
	ok = ok and player.stamina == 78.0
	player.wants_block = true
	player.update_sprint(1.0)
	ok = ok and not player.sprinting
	player.wants_block = false
	player.skills.credit(6, 100)
	ok = ok and player.skills.read_scroll("firebolt") and player.skills.assign_slot(0, "firebolt")
	ok = ok and player.activate(0) and player.mana == 85.0
	ok = ok and player.advance_cast(0.2) == "" and player.advance_cast(0.3) == "firebolt"
	ok = ok and not player.activate(0)
	ok = ok and Projectiles.segment_hit(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 0, 0), 1.0) >= 0
	ok = ok and Projectiles.segment_hit(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 3, 0), 1.0) < 0
	ok = ok and Combat.aim_direction(0.0, 0.0).is_equal_approx(Vector3.FORWARD)
	ok = ok and Combat.aim_direction(0.0, PI / 4.0).y > 0.7
	ok = ok and Combat.aim_direction(PI / 2.0, -PI / 4.0).x < -0.7
	var world := World.new()
	root.add_child(world)
	world.build(42069, false)
	player.look_pitch = 0.25
	world.cast(player, 1, "fireball")
	var shot: Dictionary = world.projectiles.shots[1]
	ok = ok and shot.velocity.y > 0.0 and shot.effect == "blast"
	ok = ok and shot.node.position.is_equal_approx(Combat.shot_origin(player))
	ok = ok and world.projectiles.state()[1][3] == "blast"
	world.projectiles.remove(1)
	var mob: Dictionary = world.monsters[2]
	mob.health = 50.0
	world.apply_spell_damage({"owner": 1, "damage": 15.0, "effect": "burn", "domain": 6, "bonus": 0.0}, mob, {1: player})
	ok = ok and mob.burn == 4.0 and mob.health == 35.0
	world.apply_spell_damage({"owner": 1, "damage": 10.0, "effect": "slow", "domain": 7, "bonus": 0.0}, mob, {1: player})
	ok = ok and mob.burn == 0.0 and mob.slow == 4.0 and mob.health == 22.5
	var bow := Player.new()
	root.add_child(bow)
	bow.setup(false, false)
	bow.inventory.reset_items(["bow", "arrows"])
	bow.inventory.add("arrows", 5)
	bow.set_trigger(true)
	ok = ok and bow.bow_drawing
	bow.advance_combat(0.45)
	ok = ok and is_equal_approx(bow.bow_charge, 0.5)
	bow.set_trigger(false)
	ok = ok and bow.attack_phase == 1 and is_equal_approx(bow.shot_power, 0.5)
	bow.advance_combat(1.0)
	bow.advance_combat(2.0)
	bow.set_trigger(true)
	bow.set_trigger(false, true)
	ok = ok and not bow.bow_drawing and bow.attack_phase == 0
	ok = ok and player.select_spell(0) and player.selected_spell == "firebolt"
	ok = ok and player.select_spell(-1) and player.selected_spell == ""
	var drops_before := world.loot.drops.size()
	world.recover_arrow(0, Vector3.ZERO)
	ok = ok and world.loot.drops.size() == drops_before + 1
	var arena := World.new()
	root.add_child(arena)
	arena.add_child(arena.projectiles)
	arena.add_child(arena.hazards)
	arena.add_child(arena.loot)
	var wall := StaticBody3D.new()
	arena.add_child(wall)
	wall.position = Vector3(0, 20, -2)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.12)
	collider.shape = shape
	wall.add_child(collider)
	await physics_frame
	await physics_frame
	var origin := Vector3(0, 20, 0)
	var hit := Projectiles.sweep(arena.get_world_3d().direct_space_state, origin, origin + Vector3.FORWARD * 8.0, 0.20, 1)
	ok = ok and not hit.is_empty() and float(hit.get("fraction", 1.0)) < 0.25
	arena.projectiles.launch(0, origin, Vector3.FORWARD, 40.0, 15.0, 30.0, Color.ORANGE, 1, false, "blast", 6)
	arena.projectiles.step(arena, {}, 0.1)
	var bounced: Dictionary = arena.projectiles.shots.get(1, {})
	ok = ok and not bounced.is_empty() and bounced.get("bounces", 0) == 1 and bounced.velocity.z > 0.0 and bounced.node.position.z > -1.8
	arena.projectiles.step(arena, {}, 0.025)
	ok = ok and arena.projectiles.shots.has(1) and arena.projectiles.shots[1].node.position.z > -1.8
	arena.free()
	if not ok:
		push_error("Magic, sprint and fireball collision tests failed")
	quit(0 if ok else 1)
