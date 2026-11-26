extends RefCounted

const Stone = preload("res://game/visuals/stone_theme.gd")

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = Stone.material(material)
	parent.add_child(node)
	node.position = at
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: String, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = 10
	shape.rings = 0
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	return mesh(parent, shape, at, material)

static func block(parent: Node3D, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, material)

static func sphere(parent: Node3D, at: Vector3, radius: float, height: float, material: String) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 8
	shape.rings = 4
	return mesh(parent, shape, at, material)

static func make(parent: Node3D, kind: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	match kind:
		"pot":
			sphere(root, Vector3.UP * 0.24, 0.24, 0.40, "clay")
			cylinder(root, Vector3.UP * 0.43, 0.12, 0.12, "clay")
			cylinder(root, Vector3.UP * 0.495, 0.15, 0.045, "clay")
			cylinder(root, Vector3.UP * 0.52, 0.10, 0.012, "dark")
		"barrel":
			cylinder(root, Vector3.UP * 0.31, 0.27, 0.62, "wood")
			for y in [0.12, 0.50]:
				cylinder(root, Vector3.UP * y, 0.285, 0.055, "iron")
		"mushrooms":
			for i in range(4):
				var point := Vector3(cos(i * 2.4) * 0.19, 0, sin(i * 2.4) * 0.19)
				var h := 0.12 + i * 0.035
				cylinder(root, point + Vector3.UP * h * 0.5, 0.025, h, "bone")
				sphere(root, point + Vector3.UP * h, 0.10, 0.08, "crystal")
		"column":
			cylinder(root, Vector3.UP * 0.15, 0.32, 0.30, "trim")
			cylinder(root, Vector3.UP * 1.55, 0.23, 2.5, "wall", 0.19)
			cylinder(root, Vector3.UP * 2.88, 0.31, 0.22, "trim")
		"table":
			block(root, Vector3.UP * 0.55, Vector3(0.88, 0.10, 0.52), "wood")
			for x in [-0.34, 0.34]:
				for z in [-0.19, 0.19]:
					block(root, Vector3(x, 0.25, z), Vector3(0.09, 0.5, 0.09), "wood")
		"chest":
			block(root, Vector3.UP * 0.19, Vector3(0.75, 0.38, 0.48), "wood")
			var lid := cylinder(root, Vector3.UP * 0.38, 0.24, 0.75, "wood")
			lid.rotation.z = PI / 2.0
			for x in [-0.26, 0.26]:
				block(root, Vector3(x, 0.23, -0.25), Vector3(0.06, 0.42, 0.03), "iron")
			block(root, Vector3(0, 0.30, -0.27), Vector3(0.10, 0.10, 0.04), "gold")
		"crate":
			block(root, Vector3.UP * 0.25, Vector3(0.58, 0.50, 0.58), "wood")
			for x in [-0.24, 0.24]:
				block(root, Vector3(x, 0.25, -0.30), Vector3(0.06, 0.50, 0.035), "iron")
		"rune":
			cylinder(root, Vector3.UP * 0.08, 0.32, 0.16, "trim")
			cylinder(root, Vector3.UP * 0.18, 0.23, 0.05, "crystal")
		_:
			block(root, Vector3.UP * 0.45, Vector3(0.48, 0.9, 0.26), "wall")
	return root

static func chain(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	for i in range(7):
		var ring := TorusMesh.new()
		ring.inner_radius = 0.035
		ring.outer_radius = 0.065
		ring.rings = 8
		ring.ring_segments = 6
		var link := mesh(root, ring, Vector3.DOWN * i * 0.095, "iron")
		link.rotation = Vector3(PI / 2.0, float(i % 2) * PI / 2.0, 0)
	return root

static func banner(parent: Node3D, at: Vector3, angle: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = angle
	block(root, Vector3.ZERO, Vector3(0.85, 0.07, 0.10), "wood")
	var cloth := block(root, Vector3.DOWN * 0.55, Vector3(0.65, 1.10, 0.025), "cloth")
	cloth.name = "Cloth"
	return root
