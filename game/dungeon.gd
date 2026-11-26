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

func generate(seed_value: int, render_geometry: bool = true, room_count: int = 9, boss_room: bool = false) -> void:
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
		visual_builder.build(tiles, seed_value, corridor_blocks)

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
