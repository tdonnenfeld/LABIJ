extends Node3D

const NetMotion = preload("res://game/network/net_motion.gd")

var shots: Dictionary = {}
var next_id := 1
var visual := false

func launch(floor_id: int, at: Vector3, direction: Vector3, speed: float, reach: float, damage: float, color: Color, source_peer: int, enemy: bool, effect: String, domain: int, bonus: float = 0.0) -> void:
	if direction.length_squared() < 0.001:
		return
	var id := next_id
	next_id += 1
	var node := make_node(at, color, effect)
	shots[id] = {"node": node, "floor": floor_id, "velocity": direction.normalized() * speed, "remaining": reach, "damage": damage, "color": color, "owner": source_peer, "enemy": enemy, "effect": effect, "domain": domain, "bonus": bonus, "fuse": 1.8, "bounces": 0}

func make_node(at: Vector3, color: Color, effect: String = "") -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visual:
		var mesh := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.20 if effect == "blast" else (0.15 if effect == "stone" else 0.095)
		shape.height = shape.radius * 2.0
		shape.radial_segments = 6
		shape.rings = 3
		mesh.mesh = shape
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		mesh.material_override = material
		node.add_child(mesh)
		var tail := MeshInstance3D.new()
		var trail := CylinderMesh.new()
		trail.top_radius = 0.025
		trail.bottom_radius = 0.07
		trail.height = 0.75 if effect in ["shock", "chain"] else (0.65 if effect.begins_with("arrow") else 0.35)
		trail.radial_segments = 5
		tail.mesh = trail
		tail.material_override = material
		node.add_child(tail)
		tail.rotation.x = PI / 2.0
		tail.position.z = trail.height * 0.5
		if effect.begins_with("arrow"):
			shape.radius = 0.035
			shape.height = 0.07
			trail.top_radius = 0.018
			trail.bottom_radius = 0.018
			material.emission_enabled = false
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
		if shot.effect == "blast":
			shot.fuse -= delta
			if shot.fuse <= 0.0:
				world.spell_blast(shot, from, actors)
				remove(id)
				continue
			shot.velocity.y -= 9.8 * delta
		elif shot.effect.begins_with("arrow") or shot.effect == "stone":
			shot.velocity.y -= 2.0 * delta
		var travel: float = shot.velocity.length() * delta if shot.effect == "blast" else minf(shot.remaining, shot.velocity.length() * delta)
		if travel < 0.00001:
			continue
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
		if not shot.enemy and shot.effect != "blast":
			var fixture_hit: float = world.projectile_fixture_hit(shot.floor, from, to, limit)
			if fixture_hit >= 0.0:
				if shot.effect.begins_with("arrow"):
					world.recover_arrow(shot.floor, from.lerp(to, fixture_hit))
				remove(id)
				continue
		if target != null:
			if shot.enemy:
				target.take_damage(shot.damage, from, shot.effect == "hex", "Enemy spell" if shot.effect == "hex" else "Enemy arrow")
			else:
				if shot.effect == "blast":
					world.spell_blast(shot, from.lerp(to, limit), actors)
				else:
					world.spell_hit(shot, target, actors)
				if shot.effect.begins_with("arrow"):
					world.recover_arrow(shot.floor, from.lerp(to, limit))
			remove(id)
		elif limit <= 1.0:
			if shot.effect == "blast":
				shot.node.position = wall.position + wall.normal * 0.06
				shot.velocity = shot.velocity.bounce(wall.normal) * 0.58
				shot.bounces += 1
				continue
			if not shot.enemy and shot.effect.begins_with("arrow"):
				world.recover_arrow(shot.floor, from.lerp(to, maxf(0.0, limit - 0.02)))
			remove(id)
		else:
			shot.node.position = to
			shot.remaining -= travel
			if shot.remaining <= 0 and shot.effect != "blast":
				if not shot.enemy and shot.effect.begins_with("arrow"):
					world.recover_arrow(shot.floor, to)
				remove(id)

func state() -> Dictionary:
	var result := {}
	for id in shots:
		var shot: Dictionary = shots[id]
		result[id] = [shot.floor, shot.node.position, shot.color, shot.effect, shot.velocity]
	return result

func apply(data: Dictionary, smooth: bool = false) -> void:
	for id in shots.keys():
		if not data.has(id):
			remove(id)
	for id in data:
		if not shots.has(id):
			shots[id] = {"node": make_node(data[id][1], data[id][2], data[id][3] if data[id].size() > 3 else ""), "floor": data[id][0], "color": data[id][2]}
		if data[id].size() > 4:
			shots[id].node.set_meta("shot_velocity", data[id][4])
		if smooth:
			NetMotion.receive(shots[id].node, data[id][1], 0.0, false, false)
		else:
			NetMotion.reset(shots[id].node)
			shots[id].node.position = data[id][1]

func visible_floor(floor_id: int) -> void:
	for shot in shots.values():
		shot.node.visible = shot.floor == floor_id

func advance_network_motion(delta: float) -> void:
	for shot in shots.values():
		NetMotion.advance(shot.node, delta)

func animate_visuals() -> void:
	if not visual:
		return
	for shot in shots.values():
		if not shot.node.visible:
			continue
		var node: Node3D = shot.node
		var previous: Vector3 = node.get_meta("visual_previous", node.position)
		var motion := node.position - previous
		if motion.length_squared() <= 0.00001:
			motion = shot.get("velocity", node.get_meta("shot_velocity", Vector3.ZERO))
		if motion.length_squared() > 0.00001:
			var direction := motion.normalized()
			node.look_at(node.global_position + direction, Vector3.FORWARD if absf(direction.y) > 0.95 else Vector3.UP)
		node.set_meta("visual_previous", node.position)
