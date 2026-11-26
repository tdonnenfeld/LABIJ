extends Node3D

const Catalog = preload("res://game/items/catalog.gd")
var drops: Dictionary = {}
var next_id := 1
var visual := false

func spawn(id: String, floor_id: int, at: Vector3) -> void:
	var drop_id := next_id
	next_id += 1
	create_drop(drop_id, id, floor_id, at)

func create_drop(drop_id: int, id: String, floor_id: int, at: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visual:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.35, 0.35)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Catalog.get_item(id).tint
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.3
		mesh.material_override = mat
		node.add_child(mesh)
		var label := Label3D.new()
		label.text = Catalog.get_item(id).title
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 0.5
		node.add_child(label)
	drops[drop_id] = {"node": node, "item": id, "floor": floor_id}

func nearest(actor) -> int:
	var best := 2.0
	var result := 0
	for id in drops:
		var drop = drops[id]
		if drop.floor != actor.floor_id:
			continue
		var distance: float = drop.node.position.distance_to(actor.position)
		if distance < best:
			best = distance
			result = id
	return result

func pickup(actor) -> bool:
	if actor.health <= 0:
		return false
	var id := nearest(actor)
	if id == 0 or not actor.inventory.add(drops[id].item):
		return false
	remove(id)
	return true

func remove(id: int) -> void:
	drops[id].node.queue_free()
	drops.erase(id)

func state() -> Dictionary:
	var result := {}
	for id in drops:
		var drop = drops[id]
		result[id] = [drop.item, drop.floor, drop.node.position]
	return result

func apply(data: Dictionary) -> void:
	for id in drops.keys():
		if not data.has(id):
			remove(id)
	for id in data:
		if not drops.has(id):
			create_drop(id, data[id][0], data[id][1], data[id][2])

func visible_floor(id: int) -> void:
	for drop in drops.values():
		drop.node.visible = drop.floor == id
