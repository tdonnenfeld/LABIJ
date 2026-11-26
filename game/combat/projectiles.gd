extends Node3D

const NetMotion = preload("res://game/network/net_motion.gd")

var shots: Dictionary = {}
var next_id := 1
var visual := false

func launch(floor_id: int, at: Vector3, direction: Vector3, speed: float, reach: float, damage: float, color: Color, source_peer: int, enemy: bool, effect: String, domain: int, bonus: float = 0.0, shooter: CollisionObject3D = null) -> void:
	if direction.length_squared() < 0.001:
		return
	var id := next_id
	next_id += 1
	var node := make_node(at, color, effect)
	shots[id] = {"node": node, "floor": floor_id, "velocity": direction.normalized() * speed, "remaining": reach, "damage": damage, "color": color, "owner": source_peer, "enemy": enemy, "effect": effect, "domain": domain, "bonus": bonus, "fuse": 1.8, "bounces": 0, "shooter": shooter}

func make_node(at: Vector3, color: Color, effect: String = "") -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visual:
		var mesh := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = radius_for(effect)
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
		if effect.begins_with("arrow") or effect == "enemy_arrow":
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

static func radius_for(effect: String) -> float:
	if effect.begins_with("arrow") or effect == "enemy_arrow":
		return 0.035
	if effect == "blast":
		return 0.20
	if effect in ["stone", "distraction"]:
		return 0.15
	return 0.095

static func sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float, mask: int, excluded: Array[RID] = []) -> Dictionary:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.collision_mask = mask
	query.exclude = excluded
	query.motion = Vector3.ZERO
	var overlap := space.get_rest_info(query)
	if not overlap.is_empty():
		overlap["fraction"] = 0.0
		return overlap
	query.motion = to - from
	var fractions := space.cast_motion(query)
	var ray := PhysicsRayQueryParameters3D.create(from, to, mask, excluded)
	ray.hit_from_inside = true
	var ray_hit := space.intersect_ray(ray)
	if not ray_hit.is_empty():
		ray_hit["fraction"] = clampf(from.distance_to(ray_hit.position) / maxf(from.distance_to(to), 0.00001) - radius / maxf(from.distance_to(to), 0.00001), 0.0, 1.0)
	if fractions.size() < 2 or fractions[0] >= 1.0:
		return ray_hit
	var fraction := fractions[0]
	query.motion = Vector3.ZERO
	query.transform.origin = from.lerp(to, minf(1.0, fractions[1] + 0.001))
	var contact := space.get_rest_info(query)
	if contact.is_empty():
		query.transform.origin = from.lerp(to, minf(1.0, fractions[1] + 0.01))
		contact = space.get_rest_info(query)
	if contact.is_empty() and not ray_hit.is_empty():
		contact = ray_hit
	if contact.is_empty():
		# A sweep still found an obstacle. Never let a projectile tunnel through it.
		contact = {"normal": (from - to).normalized(), "collider_id": 0}
	contact["fraction"] = fraction
	if not ray_hit.is_empty() and float(ray_hit.fraction) < fraction:
		return ray_hit
	return contact

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
		elif shot.effect.begins_with("arrow") or shot.effect in ["stone", "enemy_arrow"]:
			shot.velocity.y -= 2.0 * delta
		var travel: float = shot.velocity.length() * delta if shot.effect == "blast" else minf(shot.remaining, shot.velocity.length() * delta)
		if travel < 0.00001:
			if shot.effect != "blast":
				remove(id)
			continue
		var to: Vector3 = from + shot.velocity.normalized() * travel
		var excluded: Array[RID] = []
		var shooter = shot.get("shooter")
		if is_instance_valid(shooter):
			excluded.append(shooter.get_rid())
		# Player shots do not hit allies. Enemy shots stop on both players and enemies.
		var mask := 1 if shot.effect == "distraction" else (7 if shot.enemy else 5)
		var hit := sweep(get_world_3d().direct_space_state, from, to, radius_for(shot.effect), mask, excluded)
		var limit: float = hit.get("fraction", 1.1)
		var impact := from.lerp(to, minf(1.0, limit))
		if shot.effect == "distraction":
			if limit <= 1.0 or shot.remaining <= travel:
				world.distraction_lands(shot, impact)
				remove(id)
			else:
				shot.node.position = to
				shot.remaining -= travel
			continue
		if not shot.enemy and shot.effect != "blast":
			var fixture_hit: float = world.projectile_fixture_hit(shot.floor, from, to, limit)
			if fixture_hit >= 0.0:
				if shot.effect.begins_with("arrow"):
					world.recover_arrow(shot.floor, from.lerp(to, fixture_hit))
				remove(id)
				continue
		if not hit.is_empty():
			var collider = instance_from_id(int(hit.get("collider_id", 0))) if int(hit.get("collider_id", 0)) != 0 else null
			var target: Dictionary = {}
			for mob in world.monsters.values():
				if mob.health > 0 and mob.floor == shot.floor and mob.node == collider:
					target = mob
					break
			if shot.enemy:
				for actor in actors.values():
					if actor.health > 0 and actor.floor_id == shot.floor and actor == collider:
						actor.take_damage(shot.damage, from, shot.effect == "hex", "Enemy spell" if shot.effect == "hex" else "Enemy arrow")
						break
				# Friendly monsters absorb the projectile without taking damage.
				world.sound(shot.floor, impact, 3.0, "impact")
				remove(id)
				continue
			if not target.is_empty():
				if shot.effect == "blast":
					world.spell_blast(shot, impact, actors)
				else:
					world.spell_hit(shot, target, actors)
			elif shot.effect == "blast":
				var normal: Vector3 = hit.get("normal", Vector3.ZERO)
				if normal.length_squared() < 0.5:
					normal = (from - to).normalized()
				normal = normal.normalized()
				# A sphere already intersecting geometry cannot safely bounce out.
				if limit <= 0.0001 and not sweep(get_world_3d().direct_space_state, from, from, radius_for("blast"), 1).is_empty():
					world.spell_blast(shot, from, actors)
					remove(id)
					continue
				shot.node.position = impact + normal * 0.025
				if shot.velocity.dot(normal) < 0.0:
					shot.velocity = shot.velocity.bounce(normal) * 0.58
				else:
					shot.velocity *= 0.58
				shot.bounces += 1
				shot.node.set_meta("impact_serial", shot.bounces)
				continue
			if shot.effect.begins_with("arrow"):
				world.recover_arrow(shot.floor, impact)
			world.sound(shot.floor, impact, 3.0, "impact")
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
		result[id] = [shot.floor, shot.node.position, shot.color, shot.effect, shot.velocity, shot.bounces]
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
		var node: Node3D = shots[id].node
		var serial: int = data[id][5] if data[id].size() > 5 else 0
		var bounced: bool = serial != int(node.get_meta("impact_serial", 0))
		node.set_meta("impact_serial", serial)
		if smooth:
			NetMotion.receive(node, data[id][1], 0.0, bounced, false)
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
