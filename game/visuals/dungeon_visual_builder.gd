extends Node3D

const StoneKit = preload("res://game/visuals/stone_theme.gd")
const CELL := 3.0
const CHUNK := 8
const LIGHT_LIMIT := 4
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var batches: Dictionary = {}
var torches: Array[Vector3] = []
var lights: Array[OmniLight3D] = []
var light_timer := 0.0

func box(id: String, at: Vector3, size: Vector3, angle: float = 0.0) -> void:
	var chunk := Vector2i(floori(at.x / (CELL * CHUNK)), floori(at.z / (CELL * CHUNK)))
	var key := "%s:%d:%d" % [id, chunk.x, chunk.y]
	if not batches.has(key):
		batches[key] = {"material": id, "transforms": []}
	var basis := Basis(Vector3.UP, angle).scaled_local(size)
	batches[key].transforms.append(Transform3D(basis, at))

func build(tiles: Dictionary, seed_value: int, corridor_blocks: Array = []) -> void:
	var narrowed: Dictionary = {}
	for block in corridor_blocks:
		var at: Vector3 = block[0]
		narrowed[Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))] = true
	for key in tiles:
		var cell: Vector2i = key
		var origin := Vector3(cell.x * CELL, 0, cell.y * CELL)
		box("floor", origin + Vector3.DOWN * 0.15, Vector3(3, 0.3, 3))
		box("ceiling", origin + Vector3.UP * 3.15, Vector3(3, 0.3, 3))
		for side in SIDES:
			if tiles.has(cell + side):
				continue
			var normal := Vector3(side.x, 0, side.y)
			var angle := PI / 2.0 if side.x != 0 else 0.0
			var at := origin + normal * 1.5
			box("wall", at + Vector3.UP * 1.5, Vector3(3, 3, 0.2), angle)
			box("trim", at - normal * 0.025 + Vector3.UP * 0.12, Vector3(3, 0.24, 0.22), angle)
			box("trim", at - normal * 0.025 + Vector3.UP * 2.88, Vector3(3, 0.24, 0.22), angle)
			var hash_value := posmod(cell.x * 73 + cell.y * 151 + side.x * 17 + side.y * 31 + seed_value, 19)
			if hash_value == 0 and not narrowed.has(cell):
				add_torch(at, normal, angle)
			if hash_value in [4, 11] and not narrowed.has(cell):
				box("wall", at - normal * 0.04 + Vector3.UP * 1.5, Vector3(0.34, 3.0, 0.20), angle)
		add_arch(tiles, cell, origin)
	for block in corridor_blocks:
		box("wall", block[0], block[1])
	flush_batches()
	for i in range(LIGHT_LIMIT):
		var light := OmniLight3D.new()
		light.light_color = Color("#ffb56a")
		light.omni_range = 8.5
		light.omni_attenuation = 1.4
		light.light_energy = 1.7
		light.shadow_enabled = false
		add_child(light)
		light.hide()
		lights.append(light)

func add_arch(tiles: Dictionary, cell: Vector2i, origin: Vector3) -> void:
	for side in [Vector2i.RIGHT, Vector2i.DOWN]:
		var across := Vector2i(-side.y, side.x)
		if not tiles.has(cell + side) or not tiles.has(cell - side) or tiles.has(cell + across) or tiles.has(cell - across):
			continue
		for direction in [side, -side]:
			var next: Vector2i = cell + direction
			if not tiles.has(next + across) and not tiles.has(next - across):
				continue
			var forward := Vector3(direction.x, 0, direction.y)
			var cross := Vector3(across.x, 0, across.y)
			var angle := PI / 2.0 if direction.x != 0 else 0.0
			var at := origin + forward * 1.35
			box("trim", at + Vector3.UP * 2.88, Vector3(3.0, 0.24, 0.32), angle)
			for sign_value in [-1.0, 1.0]:
				box("trim", at + cross * sign_value * 1.40 + Vector3.UP * 1.45, Vector3(0.14, 2.90, 0.32), angle)
				box("wall", at + cross * sign_value * 1.25 + Vector3.UP * 2.75, Vector3(0.42, 0.30, 0.32), angle)

func add_torch(at: Vector3, normal: Vector3, angle: float) -> void:
	var stem := at - normal * 0.24 + Vector3.UP * 1.75
	box("iron", at - normal * 0.14 + Vector3.UP * 1.7, Vector3(0.20, 0.28, 0.12), angle)
	box("wood", stem, Vector3(0.11, 0.44, 0.11), angle)
	box("iron", stem + Vector3.UP * 0.22, Vector3(0.20, 0.13, 0.20), angle)
	box("flame", stem + Vector3.UP * 0.36, Vector3(0.17, 0.24, 0.17), PI / 4)
	box("ember", stem + Vector3.UP * 0.42, Vector3(0.09, 0.22, 0.09))
	torches.append(stem - normal * 0.18 + Vector3.UP * 0.32)

func flush_batches() -> void:
	for batch in batches.values():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = StoneKit.material(batch.material)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = batch.transforms.size()
		for i in range(multimesh.instance_count):
			multimesh.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		add_child(instance)

func update_lighting(viewer: Vector3, delta: float) -> void:
	light_timer -= delta
	if light_timer <= 0.0:
		light_timer = 0.25
		var nearest: Array[Vector3] = []
		for at in torches:
			if at.distance_squared_to(viewer) <= 16.0 * 16.0:
				nearest.append(at)
		nearest.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(viewer) < b.distance_squared_to(viewer))
		for i in range(lights.size()):
			lights[i].visible = i < nearest.size()
			if lights[i].visible:
				lights[i].position = nearest[i]
	var time := float(Time.get_ticks_msec()) / 1000.0
	for i in range(lights.size()):
		if lights[i].visible:
			var phase := lights[i].position.x * 0.8 + lights[i].position.z * 0.6
			lights[i].light_energy = 1.65 + 0.14 * sin(time * 7.7 + phase) + 0.09 * sin(time * 13.0 + phase)

static func route_marker(parent: Node3D, at: Vector3, color: Color, descending: bool) -> void:
	var stone := StoneKit.material("wall")
	var accent := StoneKit.solid(color, 0.65)
	for i in range(3):
		var step := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.7, 0.045, 0.52)
		step.mesh = mesh
		step.material_override = stone
		parent.add_child(step)
		step.position = at + Vector3(0, 0.025 + float(i) * 0.045, (float(i) - 1.0) * 0.53 * (1.0 if descending else -1.0))
		var rim := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(1.72, 0.025, 0.045)
		rim.mesh = strip
		rim.material_override = accent
		step.add_child(rim)
		rim.position = Vector3(0, 0.033, 0.24)
