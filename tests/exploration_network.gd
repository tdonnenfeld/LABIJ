extends SceneTree

const Dungeon = preload("res://game/dungeon.gd")
const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const NetMotion = preload("res://game/network/net_motion.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	for seed_value in [0, 1, 123, 42069, 98123, -19]:
		var level := Dungeon.new()
		root.add_child(level)
		level.generate(seed_value, false, 9)
		check(not level.loops.is_empty(), "Alternate corridor loop")
		for path in level.loops:
			for cell in path:
				check(level.tiles.has(cell), "Loop tiles accessible")
		for cell in level.hidden_tiles:
			check(not level.tiles.has(cell), "Hidden tiles absent before discovery")
		if not level.hidden_tiles.is_empty():
			check(level.secret_door.collision_layer == 1, "Secret door physically closed")
			check(level.reveal_secret() and not level.reveal_secret(), "Secret reveal idempotent")
			check(level.secret_door.collision_layer == 0, "Secret door open")
			for cell in level.hidden_tiles:
				check(level.tiles.has(cell), "Secret becomes explorable")
		level.free()
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	var secrets := 0
	for floor_id in world.floors:
		var level = world.floors[floor_id]
		if level.hidden_tiles.is_empty():
			continue
		secrets += 1
		actor.floor_id = floor_id
		actor.position = level.secret_position() - Vector3(level.secret_direction.x, 0, level.secret_direction.y) + Vector3.UP
		var count := world.loot.drops.size()
		check(world.discover_secret(actor) and not world.discover_secret(actor) and world.loot.drops.size() == count + 2, "Secret treasure only once")
	check(secrets > 0 and world.secret_state().size() == secrets, "Secret state replicated")
	check(not world.escape_entries.is_empty(), "Escape shaft exists")
	for floor_id in world.escape_entries:
		var at: Vector3 = world.escape_entries[floor_id]
		check(world.route_at(floor_id, at).get("locked", false), "Escape shaft locked before Jewel")
		world.objective.started = true
		var route := world.route_at(floor_id, at)
		check(route.step == -1 and route.destination < floor_id, "Escape shaft leads upward")
		world.objective.started = false
	actor.free()
	world.free()
	var node := Node3D.new()
	root.add_child(node)
	NetMotion.receive(node, Vector3.ZERO, 0.0)
	NetMotion.receive(node, Vector3.RIGHT, PI * 0.5)
	check(node.position == Vector3.ZERO, "Snapshot does not teleport")
	NetMotion.advance(node, NetMotion.INTERVAL * 0.5)
	check(is_equal_approx(node.position.x, 0.5) and is_equal_approx(node.rotation.y, PI * 0.375), "Halfway interpolation")
	NetMotion.advance(node, NetMotion.INTERVAL)
	check(node.position == Vector3.RIGHT, "Interpolation converges")
	NetMotion.receive(node, Vector3(0, -30, 0), 0, true)
	check(node.position.y == -30, "Floor transitions snap")
	node.free()
	var arena := World.new()
	root.add_child(arena)
	arena.add_child(arena.hazards)
	arena.add_child(arena.projectiles)
	arena.add_child(arena.loot)
	arena.spawn_monster(0, 0, "goblin", Vector3(1.5, 0, 0), 1, false)
	var mob: Dictionary = arena.monsters[0]
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	player.position = Vector3(0, 0.85, 0)
	await physics_frame
	await physics_frame
	var collision := player.move_and_collide(Vector3(2, 0, 0), true)
	check(collision != null and collision.get_collider() == mob.node, "Monster blocks player")
	mob.health = 0.0
	arena.set_monster_collision(mob)
	await physics_frame
	await physics_frame
	check(player.move_and_collide(Vector3(2, 0, 0), true) == null, "Dead monster does not block")
	arena.free()
	player.free()
	await process_frame
	quit(0 if failures == 0 else 1)
