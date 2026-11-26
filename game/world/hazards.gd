extends Node3D

var traps: Dictionary = {}
var visual := false

func add_trap(id: int, floor_id: int, at: Vector3, kind: String) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visual:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(1.25, 0.08, 1.25)
		mesh.mesh = shape
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#9b7150") if kind == "spike" else Color("#ae5432")
		mesh.material_override = mat
		node.add_child(mesh)
	traps[id] = {"node": node, "floor": floor_id, "kind": kind, "phase": 0, "timer": 0.0}

func step(actors: Dictionary, delta: float) -> void:
	for trap in traps.values():
		if trap.phase == 2:
			continue
		if trap.phase == 0:
			for actor in actors.values():
				if actor.health > 0 and actor.floor_id == trap.floor and distance(actor.position, trap.node.position) <= 0.8:
					trap.phase = 1
					trap.timer = 0.65
					break
		else:
			trap.timer -= delta
			if trap.timer > 0:
				continue
			trap.phase = 2
			for actor in actors.values():
				if actor.health > 0 and actor.floor_id == trap.floor and distance(actor.position, trap.node.position) <= (1.4 if trap.kind == "spike" else 2.0):
					actor.take_damage(18.0 if trap.kind == "spike" else 25.0, trap.node.position, trap.kind == "fire", "Spike trap" if trap.kind == "spike" else "Fire trap")

func state() -> Dictionary:
	var result := {}
	for id in traps:
		result[id] = traps[id].phase
	return result

func apply(data: Dictionary) -> void:
	for id in data:
		if traps.has(id):
			traps[id].phase = data[id]

func visible_floor(floor_id: int) -> void:
	for trap in traps.values():
		trap.node.visible = trap.floor == floor_id
		if visual:
			var mesh: MeshInstance3D = trap.node.get_child(0)
			mesh.material_override.albedo_color = Color("#f2bd4f") if trap.phase == 1 else (Color("#353330") if trap.phase == 2 else (Color("#9b7150") if trap.kind == "spike" else Color("#ae5432")))

static func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
