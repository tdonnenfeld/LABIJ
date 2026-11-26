extends RefCounted

const Loot = preload("res://game/items/loot_models.gd")
static var scenes: Dictionary = {}
static var textured_materials: Dictionary = {}
static var grain_texture: ImageTexture
const CHARACTERS := ["rat", "goblin", "brute", "archer", "guardian", "mage", "crypt_warden", "ember_oracle", "jewel_sentinel", "jewel_hunter", "adventurer"]

static func character(kind: String, parent: Node3D) -> Node3D:
	var id := kind if kind in CHARACTERS else "adventurer"
	var path := "res://art/models/characters/%s.gltf" % id
	if not scenes.has(id) and ResourceLoader.exists(path, "PackedScene"):
		scenes[id] = load(path)
	var model: Node3D
	if scenes.has(id) and scenes[id] is PackedScene:
		model = scenes[id].instantiate() as Node3D
	if not model:
		model = Node3D.new()
		var body := Node3D.new()
		body.name = "Body"
		model.add_child(body)
		Loot.gem(body, Vector3(0, 0.5, 0), 0.30, Loot.LEATHER)
		Loot.gem(body, Vector3(0, 0.92, 0), 0.16, Loot.STEEL)
	parent.add_child(model)
	apply_texture(model)
	return model

static func held(id: String, parent: Node3D, left: bool = false) -> Node3D:
	if id in ["unarmed", "empty_shield", ""]:
		return null
	var model := Loot.build(id, parent)
	model.position = Vector3.ZERO
	model.rotation.x = -PI / 2.0 if left else PI / 2.0
	return model

static func replace_held(old: Node3D, id: String, parent: Node3D, left: bool = false) -> Node3D:
	if is_instance_valid(old):
		old.hide()
		old.queue_free()
	return held(id, parent, left)

static func grain() -> ImageTexture:
	if grain_texture:
		return grain_texture
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in range(16):
		for x in range(16):
			var value := 0.76 + float(posmod(x * 73 + y * 151 + x * y * 17, 23)) / 100.0
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	grain_texture = ImageTexture.create_from_image(image)
	return grain_texture

static func apply_texture(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh and child.mesh.get_surface_count() > 0:
			var base: Material = child.get_active_material(0)
			if base is StandardMaterial3D:
				var key := base.get_instance_id()
				if not textured_materials.has(key):
					var mat: StandardMaterial3D = base.duplicate()
					mat.albedo_texture = grain()
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
					textured_materials[key] = mat
				child.material_override = textured_materials[key]
		if child is Node3D:
			apply_texture(child)
