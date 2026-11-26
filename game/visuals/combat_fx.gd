extends Node3D

const LIMIT := 24
var bursts: Array = []
var viewed_floor := 0
var mesh: BoxMesh
var materials: Dictionary = {}

func _ready() -> void:
	mesh = BoxMesh.new()
	mesh.size = Vector3.ONE

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[color] = mat
	return materials[color]

func burst(at: Vector3, floor_id: int, style: String, seed_value: int = 0) -> void:
	if floor_id != viewed_floor or style not in ["damage", "magic", "blocked", "incoming"]:
		return
	if bursts.size() >= LIMIT:
		var oldest: Dictionary = bursts.pop_front()
		oldest.node.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var node := Node3D.new()
	add_child(node)
	node.position = at
	var color: Color = {"damage": Color("#8f3633"), "magic": Color("#c4a1eb"), "blocked": Color("#e3ce89"), "incoming": Color("#913a35")}[style]
	var particles: Array = []
	for i in range(12 if style == "magic" else (9 if style == "blocked" else 7)):
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = material(color)
		part.scale = Vector3.ONE * rng.randf_range(0.035, 0.065)
		if style == "blocked":
			part.scale.y *= 2.5
		node.add_child(part)
		particles.append({"node": part, "velocity": Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(0.4, 2.3), rng.randf_range(-1.8, 1.8))})
	bursts.append({"node": node, "floor": floor_id, "age": 0.0, "particles": particles})

func _process(delta: float) -> void:
	for i in range(bursts.size() - 1, -1, -1):
		var entry: Dictionary = bursts[i]
		entry.age += delta
		entry.node.visible = entry.floor == viewed_floor
		for part in entry.particles:
			part.velocity.y -= 5.0 * delta
			part.node.position += part.velocity * delta
			part.node.rotation += Vector3.ONE * delta * 4.0
		if entry.age >= 0.38:
			entry.node.queue_free()
			bursts.remove_at(i)

func reset() -> void:
	for entry in bursts:
		entry.node.queue_free()
	bursts.clear()

func lightning(from: Vector3, to: Vector3, floor_id: int, seed_value: int) -> void:
	if floor_id != viewed_floor or from.distance_squared_to(to) < 0.001:
		return
	if bursts.size() >= LIMIT:
		var oldest: Dictionary = bursts.pop_front()
		oldest.node.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var node := Node3D.new()
	add_child(node)
	var previous := from
	for i in range(1, 9):
		var point := from.lerp(to, float(i) / 8.0)
		if i < 8:
			point += Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = material(Color("#f1e8a5"))
		node.add_child(part)
		part.position = (previous + point) * 0.5
		var direction := point - previous
		if direction.length_squared() > 0.00001:
			part.look_at(part.global_position + direction, Vector3.FORWARD if absf(direction.normalized().y) > 0.95 else Vector3.UP)
		part.scale = Vector3(0.045, 0.045, direction.length())
		previous = point
	bursts.append({"node": node, "floor": floor_id, "age": 0.20, "particles": []})
