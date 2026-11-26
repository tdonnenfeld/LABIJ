extends Node3D

const CELL := 3.0
const SINGLE_FILE := 1.2
const PASSING := 1.9
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const VisualBuilder = preload("res://game/visuals/dungeon_visual_builder.gd")
var visual_builder: Node3D
var debug_geometry := false
var tiles: Dictionary = {}
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var visual := true
var end_cell := Vector2i.ZERO
var rooms: Array[Vector2i] = []
var room_bounds: Array[Rect2i] = []
var room_tiles: Dictionary = {}
var corridor_widths: Dictionary = {}
var corridor_blocks: Array = []
var loops: Array = []
var side_rooms: Array[Vector2i] = []
var side_bounds: Array[Rect2i] = []
var hidden_tiles: Dictionary = {}
var hidden_room := Vector2i.ZERO
var secret_anchor := Vector2i.ZERO
var secret_direction := Vector2i.ZERO
var secret_door: StaticBody3D
var secret_open := false

func generate(seed_value: int, render_geometry: bool = true, room_count: int = 9, boss_room: bool = false, theme_id: int = 0) -> void:
	visual = render_geometry
	debug_geometry = "--debug-geometry" in OS.get_cmdline_user_args()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if visual and debug_geometry:
		floor_material = StandardMaterial3D.new()
		wall_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color("#514d43")
		wall_material.albedo_color = Color("#77705e")
	make_layout(rng, maxi(1, room_count), boss_room)
	for key in tiles:
		var p: Vector2i = key
		var origin := Vector3(p.x * CELL, 0, p.y * CELL)
		add_box(origin + Vector3(0, -0.15, 0), Vector3(CELL, 0.3, CELL), floor_material)
		add_box(origin + Vector3(0, 3.15, 0), Vector3(CELL, 0.3, CELL), wall_material)
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not tiles.has(p + d):
				var offset := Vector3(d.x, 0, d.y) * CELL * 0.5
				var dimensions := Vector3(0.2, 3, CELL) if d.x != 0 else Vector3(CELL, 3, 0.2)
				add_box(origin + offset + Vector3.UP * 1.5, dimensions, wall_material)

	for block in corridor_blocks:
		add_box(block[0], block[1], wall_material)

	if visual and not debug_geometry:
		visual_builder = VisualBuilder.new()
		add_child(visual_builder)
		visual_builder.build(tiles, seed_value, corridor_blocks, theme_id)
	if not hidden_tiles.is_empty():
		build_secret_door()
		for cell in hidden_tiles:
			tiles.erase(cell)

func add_box(at: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	if visual and debug_geometry:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = dimensions
		mesh.mesh = box
		mesh.material_override = material
		body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = at

func make_layout(rng: RandomNumberGenerator, count: int, boss_room: bool) -> void:
	var previous := Vector2i.ZERO
	var previous_bounds := Rect2i()
	for i in range(count):
		var center := Vector2i.ZERO
		var dimensions := Vector2i(2 + rng.randi_range(0, 1), 2 + rng.randi_range(0, 1))
		if i == 0 or i == count - 1:
			dimensions = Vector2i(3, 3)
		if i == count - 1 and boss_room:
			dimensions = Vector2i(5, 5)
		if i > 0:
			center = previous + Vector2i(rng.randi_range(6, 8), rng.randi_range(-4, 4))
		var bounds := Rect2i(center - Vector2i(floori(dimensions.x * 0.5), floori(dimensions.y * 0.5)), dimensions)
		rooms.append(center)
		room_bounds.append(bounds)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var cell := Vector2i(x, y)
				tiles[cell] = true
				room_tiles[cell] = true
		if i > 0:
			var bend := floori(float(previous_bounds.end.x + bounds.position.x - 1) * 0.5)
			carve_line(previous, Vector2i(bend, previous.y))
			carve_line(Vector2i(bend, previous.y), Vector2i(bend, center.y))
			carve_line(Vector2i(bend, center.y), center)
		previous = center
		previous_bounds = bounds
	end_cell = previous
	add_optional_layout(rng)
	var cells: Array = tiles.keys()
	cells.sort()
	var narrow_count := 0
	for cell in cells:
		if room_tiles.has(cell):
			continue
		var axis := Vector2i.ZERO
		for side in [Vector2i.RIGHT, Vector2i.DOWN]:
			var cross := Vector2i(-side.y, side.x)
			if tiles.has(cell + side) and tiles.has(cell - side) and not tiles.has(cell + cross) and not tiles.has(cell - cross):
				axis = side
				break
		if axis == Vector2i.ZERO:
			continue
		var width := SINGLE_FILE if narrow_count == 0 or rng.randf() < 0.6 else PASSING
		if width == SINGLE_FILE:
			narrow_count += 1
		corridor_widths[cell] = {"axis": axis, "width": width}
		var depth := (CELL - width) * 0.5
		var across := Vector3(-axis.y, 0, axis.x)
		var origin := Vector3(cell.x * CELL, 1.5, cell.y * CELL)
		var dimensions := Vector3(CELL, 3.0, depth) if axis.x != 0 else Vector3(depth, 3.0, CELL)
		for side in [-1.0, 1.0]:
			corridor_blocks.append([origin + across * side * (width * 0.5 + depth * 0.5), dimensions])

func carve_line(from: Vector2i, to: Vector2i) -> void:
	var cell := from
	tiles[cell] = true
	while cell != to:
		cell += Vector2i(signi(to.x - cell.x), signi(to.y - cell.y))
		tiles[cell] = true

func line_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [from]
	var at := from
	while at != to:
		at += Vector2i(signi(to.x - at.x), signi(to.y - at.y))
		result.append(at)
	return result

func edge_cell(bounds: Rect2i, center: Vector2i, sign_value: int) -> Vector2i:
	return Vector2i(center.x, bounds.end.y - 1 if sign_value > 0 else bounds.position.y)

func add_optional_layout(rng: RandomNumberGenerator) -> void:
	if rooms.size() < 3:
		return
	var pairs: Array = []
	for i in range(rooms.size() - 2):
		pairs.append([i, i + 2])
	for i in range(rooms.size() - 1):
		pairs.append([i, i + 1])
	var limit := mini(3, maxi(1, floori(rooms.size() / 5.0)))
	# A second path outside the occupied band connects existing rooms.
	for pair in pairs:
		if loops.size() >= limit:
			break
		var a: int = pair[0]
		var b: int = pair[1]
		var first_sign := 1 if rng.randf() < 0.5 else -1
		for sign_value in [first_sign, -first_sign]:
			var start := edge_cell(room_bounds[a], rooms[a], sign_value)
			var finish := edge_cell(room_bounds[b], rooms[b], sign_value)
			var outer := start.y
			for cell in tiles:
				if cell.x >= start.x and cell.x <= finish.x:
					outer = maxi(outer, cell.y) if sign_value > 0 else mini(outer, cell.y)
			outer += sign_value * 3
			var path := line_cells(start, Vector2i(start.x, outer))
			path.append_array(line_cells(Vector2i(start.x, outer), Vector2i(finish.x, outer)))
			path.append_array(line_cells(Vector2i(finish.x, outer), finish))
			var fresh := 0
			for cell in path:
				if not tiles.has(cell):
					fresh += 1
			if fresh < 4:
				continue
			for cell in path:
				tiles[cell] = true
			loops.append(path)
			break
	# Place side pockets without accidental connections to existing passages.
	var indices: Array[int] = []
	for i in range(1, rooms.size() - 1):
		indices.append(i)
	indices.reverse()
	for i in indices:
		if side_rooms.size() >= 2 and not hidden_tiles.is_empty():
			break
		var first_sign := 1 if rng.randf() < 0.5 else -1
		for sign_value in [first_sign, -first_sign]:
			var anchor := edge_cell(room_bounds[i], rooms[i], sign_value)
			var direction := Vector2i(0, sign_value)
			var center := anchor + direction * 5
			var bounds := Rect2i(center - Vector2i.ONE, Vector2i(3, 3))
			var candidate := {}
			for cell in line_cells(anchor + direction, center):
				candidate[cell] = true
			for y in range(bounds.position.y, bounds.end.y):
				for x in range(bounds.position.x, bounds.end.x):
					candidate[Vector2i(x, y)] = true
			var clear := true
			for cell in candidate:
				if tiles.has(cell):
					clear = false
					break
				for side in SIDES:
					if tiles.has(cell + side) and cell + side != anchor:
						clear = false
						break
				if not clear:
					break
			if not clear:
				continue
			for cell in candidate:
				tiles[cell] = true
			if side_rooms.size() >= 2 and hidden_tiles.is_empty():
				hidden_tiles = candidate
				hidden_room = center
				secret_anchor = anchor
				secret_direction = direction
			else:
				side_rooms.append(center)
				side_bounds.append(bounds)
				for y in range(bounds.position.y, bounds.end.y):
					for x in range(bounds.position.x, bounds.end.x):
						room_tiles[Vector2i(x, y)] = true
			break
	# Small floors may only have room for one pocket; prefer a hidden chamber
	# if a second optional branch exists but a third site could not be found.
	if hidden_tiles.is_empty() and side_rooms.size() > 1:
		var center := side_rooms[-1]
		var bounds := side_bounds[-1]
		var direction := Vector2i.ZERO
		var anchor := Vector2i.ZERO
		for i in indices:
			for sign_value in [-1, 1]:
				var edge := edge_cell(room_bounds[i], rooms[i], sign_value)
				if edge + Vector2i(0, sign_value) * 5 == center:
					anchor = edge
					direction = Vector2i(0, sign_value)
		if direction != Vector2i.ZERO:
			hidden_room = center
			secret_anchor = anchor
			secret_direction = direction
			for cell in line_cells(anchor + direction, center):
				hidden_tiles[cell] = true
			for y in range(bounds.position.y, bounds.end.y):
				for x in range(bounds.position.x, bounds.end.x):
					var cell := Vector2i(x, y)
					hidden_tiles[cell] = true
					room_tiles.erase(cell)
			side_rooms.pop_back()
			side_bounds.pop_back()

func secret_position() -> Vector3:
	return position + Vector3(secret_anchor.x * CELL, 0, secret_anchor.y * CELL) + Vector3(secret_direction.x, 0, secret_direction.y) * CELL * 0.5

func build_secret_door() -> void:
	var normal := Vector3(secret_direction.x, 0, secret_direction.y)
	var at := Vector3(secret_anchor.x * CELL, 1.5, secret_anchor.y * CELL) + normal * CELL * 0.5
	var extent := Vector3(CELL, 3.0, 0.2)
	if secret_direction.x != 0:
		extent = Vector3(0.2, 3.0, CELL)
	secret_door = StaticBody3D.new()
	secret_door.name = "SecretMasonry"
	add_child(secret_door)
	secret_door.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collision.shape = shape
	if visual:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = extent
		mesh.mesh = box
		mesh.material_override = wall_material if debug_geometry else VisualBuilder.StoneKit.material("wall")
		secret_door.add_child(mesh)
		var seam := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.025, 1.65, 0.025)
		seam.mesh = line
		seam.material_override = VisualBuilder.StoneKit.solid(Color("#493d30"))
		secret_door.add_child(seam)
		seam.position = -normal * 0.115
	secret_door.add_child(collision)

func reveal_secret() -> bool:
	if secret_open or hidden_tiles.is_empty():
		return false
	secret_open = true
	for cell in hidden_tiles:
		tiles[cell] = true
	if is_instance_valid(secret_door):
		secret_door.collision_layer = 0
		secret_door.hide()
	return true
