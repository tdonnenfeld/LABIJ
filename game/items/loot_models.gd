extends RefCounted

const Catalog = preload("res://game/items/catalog.gd")
static var materials: Dictionary = {}
const STEEL := Color("#a5ada5")
const WOOD := Color("#815734")
const BRASS := Color("#b9944f")
const LEATHER := Color("#966a43")

static func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.75
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.16
		materials[color] = mat
	return materials[color]

static func part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, angle: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	node.rotation = angle
	return node

static func box(parent: Node3D, at: Vector3, extent: Vector3, color: Color, angle: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = extent
	part(parent, mesh, at, color, angle)

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, tip: float = -1.0, angle: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if tip < 0.0 else tip
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 0
	part(parent, mesh, at, color, angle)

static func gem(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.7
	mesh.radial_segments = 6
	mesh.rings = 3
	part(parent, mesh, at, color)

static func blade(parent: Node3D, at: Vector3, width: float, length: float, color: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-width * 0.5, 0, 0), Vector3(0, 0.022, 0), Vector3(width * 0.5, 0, 0), Vector3(0, -0.022, 0), Vector3(0, 0, -length)]
	for i in range(4):
		surface.add_vertex(points[i])
		surface.add_vertex(points[(i + 1) % 4])
		surface.add_vertex(points[4])
	surface.generate_normals()
	part(parent, surface.commit(), at, color)

static func rod(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, start.distance_to(end))
	var node := part(parent, mesh, (start + end) * 0.5, color)
	node.look_at(parent.to_global(end), Vector3.UP)

static func build(id: String, parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "ItemModel"
	parent.add_child(model)
	model.position.y = -0.16
	var base := id.get_slice(":", 0)
	var item = Catalog.get_item(id)
	var tint: Color = item.tint if item != null else STEEL
	var flat := Vector3(PI / 2.0, 0, 0)
	match base:
		"sword", "venom_dagger", "spear":
			var length := 0.51 if base == "sword" else (0.27 if base == "venom_dagger" else 0.22)
			var handle := 0.72 if base == "spear" else 0.20
			box(model, Vector3(0, 0, handle * 0.25), Vector3(0.045, 0.045, handle), WOOD)
			var base_at := -handle * 0.25
			box(model, Vector3(0, 0, base_at), Vector3(0.10 if base == "spear" else 0.22, 0.04, 0.045), BRASS)
			blade(model, Vector3(0, 0, base_at), 0.085 if base == "venom_dagger" else 0.12, length, STEEL if base != "venom_dagger" else Color("#789568"))
			gem(model, Vector3(0, 0, handle * 0.75), 0.04, BRASS)
		"axe":
			box(model, Vector3.ZERO, Vector3(0.05, 0.05, 0.65), WOOD)
			box(model, Vector3(0.10, 0, -0.23), Vector3(0.25, 0.06, 0.22), STEEL)
			box(model, Vector3(0.23, 0, -0.23), Vector3(0.035, 0.08, 0.26), Color("#d9d9c5"))
		"bow", "longbow":
			var points := [Vector3(0, 0, -0.34), Vector3(0.15, 0, -0.23), Vector3(0.22, 0, 0), Vector3(0.15, 0, 0.23), Vector3(0, 0, 0.34)]
			for i in range(points.size() - 1):
				rod(model, points[i], points[i + 1], 0.055, WOOD)
			rod(model, points[0], points[-1], 0.012, Color("#d5c19a"))
		"staff", "ember_staff", "oracle_staff":
			box(model, Vector3.ZERO, Vector3(0.06, 0.06, 0.72), WOOD)
			cylinder(model, Vector3(0, 0, -0.34), 0.095, 0.13, BRASS, 0.07, flat)
			gem(model, Vector3(0, 0.05, -0.40), 0.10, Color("#87927c") if base == "staff" else tint)
		"shield", "iron_shield", "warden_shield":
			cylinder(model, Vector3.ZERO, 0.28, 0.055, BRASS)
			cylinder(model, Vector3(0, 0.04, 0), 0.25, 0.04, WOOD if base == "shield" else STEEL)
			gem(model, Vector3(0, 0.08, 0), 0.09, BRASS)
		"leather", "mail", "ward_mail":
			box(model, Vector3.ZERO, Vector3(0.37, 0.11, 0.43), LEATHER if base == "leather" else STEEL)
			for x in [-0.23, 0.23]:
				box(model, Vector3(x, 0, -0.12), Vector3(0.16, 0.09, 0.19), LEATHER if base == "leather" else STEEL)
			box(model, Vector3(0, 0.07, 0.12), Vector3(0.37, 0.025, 0.055), WOOD)
			gem(model, Vector3(0, 0.08, 0), 0.055, Color("#a38ab3") if base == "ward_mail" else BRASS)
		"iron_helm":
			gem(model, Vector3(0, 0.08, 0), 0.17, STEEL)
			box(model, Vector3(0, 0.02, -0.13), Vector3(0.20, 0.13, 0.06), STEEL)
		"leather_gloves", "iron_boots":
			for x in [-0.10, 0.10]:
				box(model, Vector3(x, 0.04, 0), Vector3(0.13, 0.10, 0.24), LEATHER if base == "leather_gloves" else STEEL)
		"ward_amulet", "ward_ring":
			var loop := TorusMesh.new()
			loop.inner_radius = 0.07
			loop.outer_radius = 0.10
			loop.rings = 8
			loop.ring_segments = 6
			part(model, loop, Vector3.ZERO, BRASS)
			gem(model, Vector3(0, 0.04, -0.09), 0.045, Color("#8c73a2"))
		"potion":
			cylinder(model, Vector3(0, 0.06, 0), 0.11, 0.20, Color("#9b4641"), 0.08)
			cylinder(model, Vector3(0, 0.20, 0), 0.045, 0.08, Color("#a0b7aa"))
			cylinder(model, Vector3(0, 0.25, 0), 0.05, 0.05, WOOD)
		"noise_stone":
			gem(model, Vector3(0, 0.025, 0), 0.14, Color("#83867a"))
		"arrows":
			for x in [-0.08, 0.0, 0.08]:
				box(model, Vector3(x, 0, 0), Vector3(0.018, 0.018, 0.45), WOOD)
				cylinder(model, Vector3(x, 0, -0.24), 0.034, 0.09, STEEL, 0.0, Vector3(-PI / 2.0, 0, 0))
				box(model, Vector3(x, 0, 0.18), Vector3(0.045, 0.018, 0.08), Color("#d5c19a"))
		_:
			if base.begins_with("scroll_"):
				cylinder(model, Vector3.ZERO, 0.075, 0.28, Color("#d5c19a"), -1.0, Vector3(0, 0, PI / 2.0))
				box(model, Vector3(0, 0.08, 0), Vector3(0.045, 0.02, 0.14), Color("#8c3935"))
			else:
				gem(model, Vector3.ZERO, 0.15, tint)
	return model
