extends Node3D

const CELL := 3.0
var tiles: Dictionary = {}
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var visual := true
var end_cell := Vector2i.ZERO

func generate(seed_value: int, render_geometry: bool = true) -> void:
	visual = render_geometry
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if visual:
		floor_material = StandardMaterial3D.new()
		wall_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color("#514d43")
		wall_material.albedo_color = Color("#77705e")
	var previous := Vector2i(0, 0)
	var heading := Vector2i.RIGHT
	for i in range(9):
		var center := previous + heading * rng.randi_range(7, 11) + Vector2i(-heading.y, heading.x) * rng.randi_range(-4, 4)
		if i == 0:
			center = Vector2i.ZERO
		var size := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))
		for x in range(-size.x, size.x + 1):
			for y in range(-size.y, size.y + 1):
				tiles[center + Vector2i(x, y)] = true
		var p := previous
		while p.x != center.x:
			p.x += signi(center.x - p.x)
			tiles[p] = true
		while p.y != center.y:
			p.y += signi(center.y - p.y)
			tiles[p] = true
		previous = center
		if rng.randf() < 0.45:
			heading = Vector2i.RIGHT if heading != Vector2i.RIGHT else (Vector2i.UP if rng.randf() < 0.5 else Vector2i.DOWN)
	end_cell = previous
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

func add_box(at: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	if visual:
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
