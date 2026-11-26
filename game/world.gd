extends Node3D

const Dungeon = preload("res://game/dungeon.gd")
const COUNT := 4
const SPACING := 30.0
const USE_RADIUS := 2.5
const FOLLOW_RADIUS := 3.0
var floors: Dictionary = {}
var monsters: Dictionary = {}
var visual := false

func build(seed_value: int, render_geometry: bool) -> void:
	visual = render_geometry
	for i in range(COUNT):
		var level := Dungeon.new()
		add_child(level)
		level.position.y = -i * SPACING
		level.generate(seed_value + i * 7919, visual)
		floors[i] = level
		if visual:
			if i > 0:
				marker(level, Vector3.ZERO, "UP [E]", Color("#67a8de"))
			if i < COUNT - 1:
				var end: Vector2i = level.end_cell
				marker(level, Vector3(end.x * Dungeon.CELL, 0, end.y * Dungeon.CELL), "DOWN [E]", Color("#d3ae55"))
		for j in range(3):
			var mob := Node3D.new()
			add_child(mob)
			var cell: Vector2i = level.end_cell - Vector2i(j + 1, 0)
			mob.position = level.position + Vector3(cell.x * Dungeon.CELL, 0.7, cell.y * Dungeon.CELL)
			if visual:
				var mesh := MeshInstance3D.new()
				var shape := CapsuleMesh.new()
				shape.radius = 0.35
				shape.height = 1.4
				mesh.mesh = shape
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color("#a64e48")
				mesh.material_override = mat
				mob.add_child(mesh)
			monsters[i * 3 + j] = {"node": mob, "floor": i, "target": 0}

func marker(level: Node3D, at: Vector3, caption: String, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.85
	shape.bottom_radius = 0.85
	shape.height = 0.15
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh.material_override = mat
	level.add_child(mesh)
	mesh.position = at + Vector3.UP * 0.08
	var label := Label3D.new()
	label.text = caption
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3.UP * 1.5
	label.modulate = color
	level.add_child(label)

func stair_position(id: int, down: bool) -> Vector3:
	var level = floors[id]
	var cell: Vector2i = level.end_cell if down else Vector2i.ZERO
	return level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)

func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func stair_at(id: int, at: Vector3) -> int:
	if id > 0 and horizontal_distance(at, stair_position(id, false)) <= USE_RADIUS:
		return -1
	if id < COUNT - 1 and horizontal_distance(at, stair_position(id, true)) <= USE_RADIUS:
		return 1
	return 0

func visible_floor(id: int) -> void:
	for key in floors:
		floors[key].visible = key == id
	for mob in monsters.values():
		mob.node.visible = mob.floor == id

func transfer(actor, peer_id: int) -> bool:
	var old: int = actor.floor_id
	var step := stair_at(old, actor.position)
	if step == 0:
		return false
	var destination := old + step
	var arrival := stair_position(destination, step < 0)
	var followers: Array = []
	for mob in monsters.values():
		if mob.floor == old and mob.target == peer_id and horizontal_distance(mob.node.position, actor.position) <= FOLLOW_RADIUS and horizontal_distance(mob.node.position, stair_position(old, step > 0)) <= FOLLOW_RADIUS:
			followers.append(mob)
	actor.floor_id = destination
	actor.position = arrival + Vector3(0, 1, 0)
	actor.velocity = Vector3.ZERO
	actor.direction = Vector2.ZERO
	for i in range(followers.size()):
		var mob = followers[i]
		mob.floor = destination
		mob.node.position = arrival + Vector3(1.0 + float(i % 3) * 0.6, 0.7, float(i / 3) * 0.6)
	return true

func simulate(actors: Dictionary, delta: float) -> void:
	for mob in monsters.values():
		var node: Node3D = mob.node
		var closest := 12.0
		var target := 0
		for id in actors:
			var actor = actors[id]
			if actor.floor_id != mob.floor:
				continue
			var distance := horizontal_distance(actor.position, node.position)
			if distance < closest:
				closest = distance
				target = id
		mob.target = target
		if target == 0 or closest < 1.0:
			continue
		var level = floors[mob.floor]
		var start := Vector2i(roundi(node.position.x / Dungeon.CELL), roundi(node.position.z / Dungeon.CELL))
		var goal := Vector2i(roundi(actors[target].position.x / Dungeon.CELL), roundi(actors[target].position.z / Dungeon.CELL))
		var next := next_cell(level.tiles, start, goal)
		var destination := Vector3(next.x * Dungeon.CELL, node.position.y, next.y * Dungeon.CELL)
		if start == goal:
			destination = Vector3(actors[target].position.x, node.position.y, actors[target].position.z)
		# Move toward tile centers before turning so walls are not crossed.
		if next != start and horizontal_distance(node.position, Vector3(start.x * Dungeon.CELL, node.position.y, start.y * Dungeon.CELL)) > 0.08:
			var center := Vector3(start.x * Dungeon.CELL, node.position.y, start.y * Dungeon.CELL)
			var offset := destination - center
			if absf(offset.x) > 0.1 and absf(node.position.z - center.z) > 0.08:
				destination = Vector3(node.position.x, node.position.y, center.z)
			elif absf(offset.z) > 0.1 and absf(node.position.x - center.x) > 0.08:
				destination = Vector3(center.x, node.position.y, node.position.z)
		node.position = node.position.move_toward(destination, delta * 2.8)

func next_cell(tiles: Dictionary, start: Vector2i, goal: Vector2i) -> Vector2i:
	if start == goal or not tiles.has(start) or not tiles.has(goal):
		return start
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == goal:
			while parents[current] != start:
				current = parents[current]
			return current
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if tiles.has(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	return start

func monster_snapshot() -> Dictionary:
	var states := {}
	for id in monsters:
		var mob = monsters[id]
		states[id] = [mob.floor, mob.node.position]
	return states

func apply_monsters(states: Dictionary) -> void:
	for id in states:
		if monsters.has(id):
			monsters[id].floor = states[id][0]
			monsters[id].node.position = states[id][1]
