extends SceneTree

const Dungeon = preload("res://game/dungeon.gd")
const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func connected(level) -> bool:
	var seen := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for side in Dungeon.SIDES:
			var next: Vector2i = cell + side
			if level.tiles.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == level.tiles.size() and seen.has(level.end_cell)

func run() -> void:
	for seed_value in [0, 1, 123, 42069, 98123, -19]:
		var level := Dungeon.new()
		root.add_child(level)
		level.generate(seed_value, false, 9, true)
		check(connected(level), "Connected dungeon")
		check(level.room_bounds.size() == 9 and level.room_bounds[-1].size == Vector2i(5, 5), "Boss chamber")
		for i in range(8):
			var extent: Vector2i = level.room_bounds[i].size
			check(extent.x >= 2 and extent.y >= 2 and extent.x <= 3 and extent.y <= 3, "Compact room")
		var single := 0
		for cell in level.corridor_widths:
			var corridor: Dictionary = level.corridor_widths[cell]
			check(not level.room_tiles.has(cell), "No pinch inside room")
			if corridor.width == Dungeon.SINGLE_FILE:
				single += 1
		check(single > 0 and level.corridor_blocks.size() == level.corridor_widths.size() * 2, "Physical single-file corridors")
		level.free()
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 8)
	var actors := {}
	for i in range(8):
		var actor := Player.new()
		root.add_child(actor)
		actor.setup(false, false)
		var landing := world.arrival_position(0, Vector3.ZERO, actors)
		check(landing != Vector3.INF and landing.length() <= 2.7, "Clear party landing")
		actor.position = landing
		actors[i] = actor
	for a in actors:
		for b in actors:
			if a != b:
				check(actors[a].position.distance_to(actors[b].position) >= 0.74, "No overlapping arrivals")
	for floor_id in world.floors:
		var count := 0
		for mob in world.monsters.values():
			if mob.floor == floor_id and not mob.boss and not mob.reserve:
				count += 1
		check(count == world.encounter_count(floor_id, 8), "Full encounter budget")
	# Isolate a pair of players and test the real physics mask.
	for actor in actors.values():
		actor.free()
	world.free()
	var first := Player.new()
	var second := Player.new()
	root.add_child(first)
	root.add_child(second)
	first.setup(false, false)
	second.setup(false, false)
	first.position = Vector3(0, 1, 0)
	second.position = Vector3(1.5, 1, 0)
	await physics_frame
	await physics_frame
	var hit := first.move_and_collide(Vector3(2, 0, 0), true)
	check(hit != null and hit.get_collider() == second, "Players physically block one another")
	first.free()
	second.free()
	quit(0 if failures == 0 else 1)
