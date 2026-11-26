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
		var level = world.floors[floor_id]
		for room in level.rooms:
			var at: Vector3 = level.position + Vector3(room.x * Dungeon.CELL, 0, room.y * Dungeon.CELL)
			for i in range(12):
				var follower := world.follower_arrival(floor_id, at, "brute", i)
				for x in [-0.55, 0.55]:
					for z in [-0.55, 0.55]:
						check(level.room_tiles.has(World.Acoustics.cell(follower + Vector3(x, 0, z))), "Follower lands inside room")
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
	var level := Dungeon.new()
	root.add_child(level)
	level.generate(123, false, 5)
	var narrow_cell := Vector2i.ZERO
	for cell in level.corridor_widths:
		if level.corridor_widths[cell].width == Dungeon.SINGLE_FILE:
			narrow_cell = cell
			break
	var axis: Vector2i = level.corridor_widths[narrow_cell].axis
	var across := Vector3(-axis.y, 0, axis.x)
	var center := Vector3(narrow_cell.x * Dungeon.CELL, 1, narrow_cell.y * Dungeon.CELL)
	var walker := Player.new()
	root.add_child(walker)
	walker.setup(false, false)
	walker.position = center
	await physics_frame
	await physics_frame
	var wall_hit := walker.move_and_collide(across, true)
	check(wall_hit != null and wall_hit.get_collider() is StaticBody3D, "Narrow corridor physically blocks lateral movement")
	if wall_hit != null:
		check(wall_hit.get_travel().length() < 0.4, "Single-file clearance matches width")
	walker.free()
	level.free()
	quit(0 if failures == 0 else 1)
