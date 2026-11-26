extends StaticBody3D

const Stone = preload("res://game/visuals/stone_theme.gd")
var opened := false
var width := 1.2
var style := "wood"
var leaf: Node3D
var amount := 0.0

func setup(at: Vector3, axis: Vector2i, span: float, kind: String, render: bool) -> void:
	position = at
	rotation.y = PI / 2.0 if axis.x != 0 else 0.0
	width = span
	style = kind
	collision_layer = 1
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 2.9, 0.14)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.45
	add_child(collision)
	if render:
		leaf = Node3D.new()
		add_child(leaf)
		if style == "wood":
			leaf.position.x = -width * 0.5
			for i in range(6):
				part(leaf, Vector3(width * (i + 0.5) / 6.0, 1.44, 0), Vector3(width / 6.0 - 0.009, 2.88, 0.12), "wood")
			for y in [0.45, 2.35]:
				part(leaf, Vector3(width * 0.5, y, -0.075), Vector3(width, 0.11, 0.055), "iron")
				part(leaf, Vector3(width * 0.5, y, 0.075), Vector3(width, 0.11, 0.055), "iron")
			for z in [-0.10, 0.10]:
				part(leaf, Vector3(width - 0.16, 1.15, z), Vector3(0.10, 0.12, 0.08), "gold")
		else:
			for i in range(7):
				part(leaf, Vector3(width * (float(i) / 6.0 - 0.5) * 0.9, 1.45, 0), Vector3(0.065, 2.9, 0.08), "iron")
			for y in [0.4, 1.5, 2.7]:
				part(leaf, Vector3(0, y, 0), Vector3(width, 0.095, 0.13), "iron")
		for side in [-1.0, 1.0]:
			part(self, Vector3(side * (width * 0.5 + 0.06), 1.45, 0), Vector3(0.12, 2.9, 0.24), "trim")
		part(self, Vector3(0, 2.94, 0), Vector3(width + 0.24, 0.12, 0.24), "trim")
	set_process(render)

func part(parent: Node3D, at: Vector3, size: Vector3, material: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Stone.material(material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	instance.position = at

func set_open(value: bool) -> void:
	opened = value
	collision_layer = 0 if opened else 1

func _process(delta: float) -> void:
	if not leaf or not is_visible_in_tree():
		return
	amount = move_toward(amount, 1.0 if opened else 0.0, delta * 3.0)
	var eased := smoothstep(0.0, 1.0, amount)
	if style == "wood":
		leaf.rotation.y = -PI * 0.5 * eased
	else:
		leaf.position.y = eased * 2.95
		leaf.visible = amount < 0.99

func obstructed(at: Vector3, radius: float = 0.55) -> bool:
	var local := to_local(at)
	return absf(local.x) <= width * 0.5 + radius and absf(local.z) <= radius + 0.12 and absf(local.y - 1.45) < 2.0
