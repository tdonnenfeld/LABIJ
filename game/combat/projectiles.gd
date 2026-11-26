extends Node3D

var shots: Dictionary = {}
var next_id := 1
var visual := false

func launch(floor_id: int, at: Vector3, direction: Vector3, speed: float, reach: float, damage: float, color: Color, source_peer: int, enemy: bool, effect: String, domain: int, bonus: float = 0.0) -> void:
	if direction.length_squared() < 0.001:
		return
	var id := next_id
	next_id += 1
	var node := make_node(at, color)
	shots[id] = {"node": node, "floor": floor_id, "velocity": direction.normalized() * speed, "remaining": reach, "damage": damage, "color": color, "owner": source_peer, "enemy": enemy, "effect": effect, "domain": domain, "bonus": bonus}

func make_node(at: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visual:
		var mesh := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.12
		shape.height = 0.24
		mesh.mesh = shape
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		mesh.material_override = material
		node.add_child(mesh)
	return node

func remove(id: int) -> void:
	shots[id].node.queue_free()
	shots.erase(id)

static func segment_hit(from: Vector3, to: Vector3, center: Vector3, radius: float) -> float:
	var v := to - from
	var offset := from - center
	var aa := v.length_squared()
	if aa <= 0.000001:
		return -1.0
	var cc := offset.length_squared() - radius * radius
	if cc <= 0:
		return 0.0
	var bb := offset.dot(v)
	var disc := bb * bb - aa * cc
	if disc < 0:
		return -1.0
	var time := (-bb - sqrt(disc)) / aa
	return time if time >= 0 and time <= 1 else -1.0

func step(world, actors: Dictionary, delta: float) -> void:
	for id in shots.keys():
		if world.objective.result != "":
			break
		var shot: Dictionary = shots[id]
		var from: Vector3 = shot.node.position
		var travel: float = minf(shot.remaining, shot.velocity.length() * delta)
		var to: Vector3 = from + shot.velocity.normalized() * travel
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		var wall := get_world_3d().direct_space_state.intersect_ray(query)
		var limit := 1.1
		if not wall.is_empty():
			limit = from.distance_to(wall.position) / maxf(travel, 0.0001)
		if shot.effect == "distraction":
			if limit <= 1.0 or shot.remaining <= travel:
				var landing := from.lerp(to, maxf(0.0, limit - 0.02)) if limit <= 1.0 else to
				world.distraction_lands(shot, landing)
				remove(id)
			else:
				shot.node.position = to
				shot.remaining -= travel
			continue
		var target = null
		if shot.enemy:
			for actor in actors.values():
				if actor.health <= 0 or actor.floor_id != shot.floor:
					continue
				var time := segment_hit(from, to, actor.position, 0.65)
				if time >= 0 and time < limit:
					limit = time
					target = actor
		else:
			for mob in world.monsters.values():
				if mob.health <= 0 or mob.floor != shot.floor:
					continue
				var radius: float = maxf(0.45, float(world.Bestiary.stats(mob.kind)[11]) * 0.5)
				var time := segment_hit(from, to, mob.node.position, radius)
				if time >= 0 and time < limit:
					limit = time
					target = mob
		if target != null:
			if shot.enemy:
				target.take_damage(shot.damage, from, shot.effect == "hex", "Enemy spell" if shot.effect == "hex" else "Enemy arrow")
			else:
				world.spell_hit(shot, target, actors)
			remove(id)
		elif limit <= 1.0:
			if shot.effect == "blast":
				world.spell_blast(shot, from.lerp(to, limit), actors)
			remove(id)
		else:
			shot.node.position = to
			shot.remaining -= travel
			if shot.remaining <= 0:
				remove(id)

func state() -> Dictionary:
	var result := {}
	for id in shots:
		var shot: Dictionary = shots[id]
		result[id] = [shot.floor, shot.node.position, shot.color]
	return result

func apply(data: Dictionary) -> void:
	for id in shots.keys():
		if not data.has(id):
			remove(id)
	for id in data:
		if not shots.has(id):
			shots[id] = {"node": make_node(data[id][1], data[id][2]), "floor": data[id][0], "color": data[id][2]}
		shots[id].node.position = data[id][1]

func visible_floor(floor_id: int) -> void:
	for shot in shots.values():
		shot.node.visible = shot.floor == floor_id
