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
