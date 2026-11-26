extends RefCounted

const Loot = preload("res://game/items/loot_models.gd")
static var scenes: Dictionary = {}
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
