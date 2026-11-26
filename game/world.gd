extends Node3D

const Numbers = preload("res://game/ui/numbers.gd")
const Acoustics = preload("res://game/world/noise.gd")
const Vision = preload("res://game/monsters/vision.gd")
const VoiceCodec = preload("res://game/audio/voice_codec.gd")
var sounds: Array = []
var awareness_rng := RandomNumberGenerator.new()

const Dungeon = preload("res://game/dungeon.gd")
const Combat = preload("res://game/combat.gd")
const Threat = preload("res://game/combat/threat.gd")
const Routes = preload("res://game/world/routes.gd")
const Objective = preload("res://game/world/objective.gd")
var objective := Objective.new()
const Journal = preload("res://game/world/journal.gd")
var journal := Journal.new()
var party_size := 1
var jewel_marker: Node3D
var gate_label: Label3D
const Hazards = preload("res://game/world/hazards.gd")
var hazards := Hazards.new()
var branch_entries: Dictionary = {}
const Bestiary = preload("res://game/monsters/bestiary.gd")
const Spells = preload("res://game/combat/spells.gd")
const Projectiles = preload("res://game/combat/projectiles.gd")
var projectiles := Projectiles.new()
const Catalog = preload("res://game/items/catalog.gd")
const Loot = preload("res://game/items/loot.gd")
var loot := Loot.new()
var loot_rng := RandomNumberGenerator.new()
var tablet_position := Vector3.ZERO
var secret_id := ""
const COUNT := Routes.COUNT
const SPACING := 30.0
const USE_RADIUS := 2.5
const FOLLOW_RADIUS := 3.0
var floors: Dictionary = {}
var monsters: Dictionary = {}
var visual := false

func build(seed_value: int, render_geometry: bool, size: int = 1) -> void:
	party_size = size
	visual = render_geometry
	hazards.visual = visual
	add_child(hazards)
	hazards.noise.connect(func(floor_id, at): emit_noise(floor_id, at, Acoustics.EXPLOSION); sound(floor_id, at, Acoustics.EXPLOSION, "explosion"))
	projectiles.visual = visual
	add_child(projectiles)
	loot.visual = visual
	add_child(loot)
	loot_rng.seed = seed_value + 53
	awareness_rng.seed = seed_value + 171
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 97
	var secrets := ["forgotten", "stone", "ancient"]
	secret_id = secrets[rng.randi_range(0, 2)]
	for i in range(COUNT):
		var level := Dungeon.new()
		add_child(level)
		level.position.y = -i * SPACING
		var room_count := (5 if i >= Routes.MAIN_COUNT else 9) + 3 * (clampi(party_size, 1, 8) - 1)
		level.generate(seed_value + i * 7919, visual, room_count, i >= Routes.MAIN_COUNT)
		floors[i] = level
		if i == 1:
			tablet_position = level.position + Vector3(3, 0, 0)
			if visual:
				marker(level, Vector3(6, 0, 0), "ANCIENT TABLET [T]", Color("#8ab8a0"))
		for branch in Routes.PARENTS:
			if Routes.PARENTS[branch] == i:
				var entry: Vector2i = level.end_cell if branch == Routes.SANCTUARY else branch_cell(level, rng)
				branch_entries[branch] = level.position + Vector3(entry.x * Dungeon.CELL, 0, entry.y * Dungeon.CELL)
				if visual:
					var label := marker(level, branch_entries[branch] - level.position, Routes.NAMES[branch] + " [E]", Color("#b98ddb"))
					if branch == Routes.SANCTUARY:
						gate_label = label
		if visual:
			if i == 0:
				marker(level, Vector3.ZERO, "SURFACE EXIT — JEWEL REQUIRED", Color("#d9d19a"))
			if i > 0:
				marker(level, Vector3.ZERO, "RETURN [E]" if i >= Routes.MAIN_COUNT else "UP [E]", Color("#67a8de"))
			if i < Routes.MAIN_COUNT - 1:
				var end: Vector2i = level.end_cell
				marker(level, Vector3(end.x * Dungeon.CELL, 0, end.y * Dungeon.CELL), "DOWN [E]", Color("#d3ae55"))
		if i == Routes.SANCTUARY:
			objective.jewel_position = stair_position(i, true)
		var cells: Array[Vector2i] = []
		for cell in level.room_tiles:
			if Vector2(cell).length() >= 4.0 and Vector2(cell - level.end_cell).length() >= 2.0 and not near_branch_entry(i, level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)):
				cells.append(cell)
		cells.sort()
		var count := mini(cells.size(), encounter_count(i, party_size))
		if i >= Routes.MAIN_COUNT:
			count += 1
		for j in range(count):
			var pool: Array = Bestiary.ENCOUNTERS[i]
			var boss := i >= Routes.MAIN_COUNT and j == count - 1
			var kind: String = Routes.BOSSES[i] if boss else pool[rng.randi_range(0, pool.size() - 1)]
			var cell: Vector2i = level.end_cell
			if not boss:
				var pick := rng.randi_range(0, cells.size() - 1)
				cell = cells[pick]
				cells.remove_at(pick)
			spawn_monster(i * 1000 + j, i, kind, level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL), party_size, boss)

		for j in range(mini(cells.size(), 2 + Routes.depth(i))):
			var pick := rng.randi_range(0, cells.size() - 1)
			var cell: Vector2i = cells[pick]
			cells.remove_at(pick)
			hazards.add_trap(i * 1000 + j, i, level.position + Vector3(cell.x * Dungeon.CELL, 0.06, cell.y * Dungeon.CELL), "spike" if rng.randf() < 0.5 else "fire")
		if i < Routes.MAIN_COUNT:
			for j in range(mini(cells.size(), ceili(clampi(party_size, 1, 8) / 2.0))):
				var pick := rng.randi_range(0, cells.size() - 1)
				var cell: Vector2i = cells[pick]
				cells.remove_at(pick)
				spawn_monster(i * 1000 + 900 + j, i, "jewel_hunter", level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL), party_size, false, true)
	if visual:
		jewel_marker = Node3D.new()
		add_child(jewel_marker)
		marker(jewel_marker, Vector3.ZERO, "THE JEWEL [E]", Color("#e9c96d"))
		jewel_marker.hide()

func spawn_monster(id: int, floor_id: int, kind: String, at: Vector3, group_size: int, boss: bool, reserve: bool = false) -> void:
	var stats := Bestiary.stats(kind)
	var mob := Node3D.new()
	add_child(mob)
	var hp: float = float(stats[1]) * (1.0 + 0.35 * (clampi(group_size, 1, 8) - 1) if boss else 1.0)
	mob.position = at + Vector3.UP * float(stats[11]) * 0.5
	mob.rotation.y = float(id % 16) * TAU / 16.0
	if visual:
		var mesh := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = stats[10]
		shape.height = stats[11]
		mesh.mesh = shape
		var mat := StandardMaterial3D.new()
		mat.albedo_color = stats[9]
		mesh.material_override = mat
		mob.add_child(mesh)
		var face := MeshInstance3D.new()
		var face_shape := BoxMesh.new()
		face_shape.size = Vector3(float(stats[10]) * 1.2, 0.09, 0.09)
		face.mesh = face_shape
		var face_material := StandardMaterial3D.new()
		face_material.albedo_color = Color("#28231d")
		face.material_override = face_material
		mesh.add_child(face)
		face.position = Vector3(0, float(stats[11]) * 0.23, -float(stats[10]))
		var label := Label3D.new()
		label.text = stats[0]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = float(stats[11]) * 0.5 + 0.3
		mob.add_child(label)
		if kind in ["crypt_warden", "jewel_sentinel"]:
			var ring := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = float(stats[3])
			disc.bottom_radius = float(stats[3])
			disc.height = 0.03
			ring.mesh = disc
			var warning := StandardMaterial3D.new()
			warning.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			warning.albedo_color = Color(1.0, 0.35, 0.08, 0.28)
			warning.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = warning
			mob.add_child(ring)
			ring.position.y = 0.04 - float(stats[11]) * 0.5
			ring.hide()

	monsters[id] = {"node": mob, "kind": kind, "floor": floor_id, "target": 0, "threat": {}, "health": 0.0 if reserve else hp, "boss": boss, "reserve": reserve, "rewarded": false, "max_health": hp, "forced_target": 0, "force_timer": 0.0, "phase": 0, "timer": 0.0, "attack_target": 0, "aim": Vector3.ZERO, "hurt": 0.0, "bleed": 0.0, "bleed_damage": 0.0, "bleed_owner": 0, "stun": 0.0, "burn": 0.0, "burn_damage": 0.0, "burn_owner": 0, "slow": 0.0, "poison": 0.0, "poison_damage": 0.0, "poison_owner": 0, "dot_amount": {}, "dot_time": 0.0, "asleep": not boss and not reserve and awareness_rng.randf() < 0.45, "investigate": 0.0, "heard_at": at, "roam_goal": Acoustics.cell(at), "roam_wait": awareness_rng.randf_range(0.5, 3.0), "stealth_seen": {}, "ambush_used": false, "backstab_seen": {}, "step_distance": 0.0}
	mob.visible = not reserve

func marker(level: Node3D, at: Vector3, caption: String, color: Color) -> Label3D:
	if level is Dungeon and not level.debug_geometry and not caption.begins_with("ANCIENT"):
		Dungeon.VisualBuilder.route_marker(level, at, color, caption.begins_with("DOWN") or not (caption.begins_with("UP") or caption.begins_with("RETURN") or caption.begins_with("SURFACE")))
	else:
		add_marker_disc(level, at, color)
	var label := Label3D.new()
	label.text = caption
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3.UP * 1.5
	label.modulate = color
	level.add_child(label)
	return label

func add_marker_disc(level: Node3D, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.85
	shape.bottom_radius = 0.85
	shape.height = 0.15
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh.material_override = mat
	level.add_child(mesh)
	mesh.position = at + Vector3.UP * 0.08

func stair_position(id: int, down: bool) -> Vector3:
	var level = floors[id]
	var cell: Vector2i = level.end_cell if down else Vector2i.ZERO
	return level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)

func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func near_branch_entry(floor_id: int, at: Vector3) -> bool:
	for branch in branch_entries:
		if Routes.PARENTS[branch] == floor_id and horizontal_distance(at, branch_entries[branch]) < 6.0:
			return true
	return false

func route_at(id: int, at: Vector3) -> Dictionary:
	if id >= Routes.MAIN_COUNT and horizontal_distance(at, stair_position(id, false)) <= USE_RADIUS:
		return {"destination": Routes.PARENTS[id], "arrival": branch_entries[id], "entry": stair_position(id, false), "label": "Return", "step": -1}
	for branch in branch_entries:
		if Routes.PARENTS[branch] == id and horizontal_distance(at, branch_entries[branch]) <= USE_RADIUS:
			if branch == Routes.SANCTUARY and not objective.gate_open():
				return {"locked": true, "label": "Sanctuary locked — %d/2 runes" % objective.runes.size(), "step": 0}
			return {"destination": branch, "arrival": stair_position(branch, false), "entry": branch_entries[branch], "label": Routes.NAMES[branch], "step": 1}
	if id > 0 and id < Routes.MAIN_COUNT and horizontal_distance(at, stair_position(id, false)) <= USE_RADIUS:
		return {"destination": id - 1, "arrival": stair_position(id - 1, true), "entry": stair_position(id, false), "label": "Ascend", "step": -1}
	if id < Routes.MAIN_COUNT - 1 and horizontal_distance(at, stair_position(id, true)) <= USE_RADIUS:
		return {"destination": id + 1, "arrival": stair_position(id + 1, false), "entry": stair_position(id, true), "label": "Descend", "step": 1}
	return {}

func stair_at(id: int, at: Vector3) -> int:
	return route_at(id, at).get("step", 0)

func visible_floor(id: int) -> void:
	hazards.visible_floor(id)
	if jewel_marker:
		jewel_marker.position = objective.jewel_position
		jewel_marker.visible = objective.guardian_defeated and objective.carrier == 0 and objective.result == "" and objective.jewel_floor == id
	if gate_label:
		gate_label.text = "JEWEL SANCTUARY [E]" if objective.gate_open() else "SANCTUARY LOCKED — %d/2 RUNES" % objective.runes.size()
	loot.visible_floor(id)
	projectiles.visible_floor(id)
	for key in floors:
		floors[key].visible = key == id
	for mob in monsters.values():
		mob.node.visible = mob.floor == id and mob.health > 0
		if visual:
			var mesh: MeshInstance3D = mob.node.get_child(0)
			mesh.material_override.albedo_color = Color("#ffffff") if mob.hurt > 0 else (Color("#e5a64e") if mob.phase == 1 else (Color("#8aa7e0") if mob.stun > 0 or mob.slow > 0 else (Color("#e96c38") if mob.burn > 0 else Bestiary.stats(mob.kind)[9])))
			var label: Label3D = mob.node.get_child(1)
			var filled := clampi(ceili(10.0 * mob.health / mob.max_health), 0, 10)
			label.text = "%s — %s\n%s%s %d/%d%s" % [Bestiary.stats(mob.kind)[0], awareness_name(mob), "█".repeat(filled), "░".repeat(10 - filled), ceili(mob.health), ceili(mob.max_health), status_summary(mob)]
			mesh.rotation.z = PI * 0.5 if mob.asleep else 0.0
			if mob.kind in ["crypt_warden", "jewel_sentinel"]:
				mob.node.get_child(2).visible = mob.phase == 1 and mob.stun <= 0

func transfer(actor, peer_id: int, actors: Dictionary = {}) -> bool:
	if objective.result != "" or actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return false
	if interact_objective(actor, peer_id):
		return true
	var old: int = actor.floor_id
	var route := route_at(old, actor.position)
	if route.is_empty() or route.get("locked", false):
		return false
	var destination: int = route.destination
	var arrival: Vector3 = route.arrival
	var landing := arrival_position(destination, arrival, actors, actor)
	if landing == Vector3.INF:
		return false
	var followers: Array = []
	for mob in monsters.values():
		if not mob.boss and mob.health > 0 and mob.floor == old and mob.target == peer_id and horizontal_distance(mob.node.position, actor.position) <= FOLLOW_RADIUS and horizontal_distance(mob.node.position, route.entry) <= FOLLOW_RADIUS:
			followers.append(mob)
	actor.floor_id = destination
	actor.position = landing
	actor.velocity = Vector3.ZERO
	actor.direction = Vector2.ZERO
	for i in range(followers.size()):
		var mob = followers[i]
		mob.phase = 0
		mob.timer = 0.0
		mob.threat = {peer_id: maxf(Threat.PULL, mob.threat.get(peer_id, 0.0))}
		mob.force_timer = 0.0
		mob.floor = destination
		mob.asleep = false
		mob.investigate = 0.0
		mob.roam_goal = Acoustics.cell(arrival)
		mob.node.position = follower_arrival(destination, arrival, mob.kind, i)
	return true

func simulate(actors: Dictionary, delta: float) -> void:
	if objective.result != "":
		return
	hazards.step(actors, delta)
	var occupied := {}
	for actor in actors.values():
		if actor.health > 0:
			occupied[actor.floor_id] = true
	for mob in monsters.values():
		if objective.result != "":
			break
		if mob.health <= 0:
			continue
		mob.dot_time += delta
		mob.hurt = maxf(0.0, mob.hurt - delta)
		mob.force_timer = maxf(0.0, mob.force_timer - delta)
		var stats := Bestiary.stats(mob.kind)
		mob.slow = maxf(0.0, mob.slow - delta)
		if mob.burn > 0:
			var burn_elapsed := minf(delta, mob.burn)
			mob.burn -= burn_elapsed
			Threat.add(mob, mob.burn_owner, minf(mob.health, mob.burn_damage * burn_elapsed))
			record_dot(mob, actors.get(mob.burn_owner), "Burning", minf(mob.health, mob.burn_damage * burn_elapsed))
			mob.health = maxf(0.0, mob.health - mob.burn_damage * burn_elapsed)
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.burn_owner), actors)
				continue
		if mob.bleed > 0:
			var elapsed := minf(delta, mob.bleed)
			mob.bleed -= elapsed
			Threat.add(mob, mob.bleed_owner, minf(mob.health, mob.bleed_damage * elapsed))
			record_dot(mob, actors.get(mob.bleed_owner), "Bleeding", minf(mob.health, mob.bleed_damage * elapsed))
			mob.health = maxf(0.0, mob.health - mob.bleed_damage * elapsed)
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.bleed_owner), actors)
				continue
		if mob.poison > 0:
			var elapsed := minf(delta, mob.poison)
			mob.poison -= elapsed
			var damage := minf(mob.health, mob.poison_damage * elapsed)
			Threat.add(mob, mob.poison_owner, damage)
			record_dot(mob, actors.get(mob.poison_owner), "Poison", damage)
			mob.health -= damage
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.poison_owner), actors)
				continue
		if mob.dot_time >= 1.0:
			flush_dots(mob)
		if mob.stun > 0:
			mob.stun = maxf(0.0, mob.stun - delta)
			continue
		var node: Node3D = mob.node
		var closest := 12.0 + objective.pressure() * 3.0
		if mob.asleep:
			closest = 1.8
		var seen := 0
		var eligible := {}
		var distances := {}
		for id in actors:
			var actor = actors[id]
			if actor.floor_id != mob.floor or actor.health <= 0:
				continue
			var distance := horizontal_distance(actor.position, node.position)
			eligible[id] = true
			distances[id] = distance
			var sight := closest
			if not mob.asleep and actor.quiet_walking:
				sight = minf(sight, (5.0 + objective.pressure() * 2.0) * (1.0 - actor.skills.bonus("concealment")))
			if distance < closest and Vision.detects(node.rotation.y, actor.position - node.position, sight, mob.asleep, Vision.arc(mob.kind)) and Combat.clear_path(node, actor.position):
				closest = distance
				seen = id
		var target := Threat.choose(mob, eligible, distances)
		if target == 0 and mob.reserve and eligible.has(objective.carrier):
			Threat.add(mob, objective.carrier, Threat.PULL)
			target = objective.carrier
		if target == 0 and seen != 0:
			Threat.add(mob, seen, Threat.PULL)
			target = seen
		if target != 0:
			wake(mob)
			mob.investigate = 0.0
			mob.roam_goal = Acoustics.cell(node.position)
		if target != mob.target and target != 0 and actors.has(target):
			journal.add("Combat", "%s targets %s" % [stats[0], actors[target].display_name])
		mob.target = target
		if target != 0:
			closest = distances[target]
		if mob.phase != 0:
			mob.timer -= delta
			if mob.timer <= 0:
				if mob.phase == 1:
					sound(mob.floor, node.position, 12.0, "bow" if mob.kind == "archer" else ("magic" if mob.kind in ["mage", "ember_oracle"] else "melee"))
					var victim = actors.get(mob.attack_target)
					if mob.kind in ["crypt_warden", "jewel_sentinel"]:
						for actor in actors.values():
							if actor.health > 0 and actor.floor_id == mob.floor and horizontal_distance(actor.position, node.position) <= float(stats[3]) and Combat.clear_path(node, actor.position):
								actor.take_damage(float(stats[2]), node.position, false, stats[0])
					elif mob.kind == "ember_oracle":
						var direction: Vector3 = mob.aim - node.position
						for angle in [-0.24, 0.0, 0.24]:
							projectiles.launch(mob.floor, node.position, direction.rotated(Vector3.UP, angle), 10.0, float(stats[3]), float(stats[2]), Color("#ef864b"), 0, true, "hex", -1)
					elif mob.kind in ["archer", "mage"]:
						var direction: Vector3 = mob.aim - node.position
						projectiles.launch(mob.floor, node.position, direction, 14.0 if mob.kind == "archer" else 9.0, float(stats[3]), float(stats[2]), Color("#d8c7a0") if mob.kind == "archer" else Color("#cf73e8"), 0, true, "hex" if mob.kind == "mage" else "", -1)
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= float(stats[3]) and Combat.clear_path(node, victim.position):
						victim.take_damage(float(stats[2]), node.position, false, stats[0])
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= 4.0:
						victim.skills.credit(5, 4)
						journal.add("Combat", "%s dodges %s" % [victim.display_name, stats[0]], victim.floor_id, victim.position + Vector3.UP, "Dodged", "blocked", int(victim.name) if str(victim.name).is_valid_int() else 0)
					mob.phase = 2
					mob.timer = float(stats[6])
				else:
					mob.phase = 0
			continue
		if target == 0:
			if not mob.asleep and occupied.has(mob.floor):
				idle_move(mob, delta)
			continue
		if closest <= float(stats[3]) and Combat.clear_path(node, actors[target].position):
			face_toward(mob, actors[target].position)
			mob.phase = 1
			mob.timer = float(stats[5])
			mob.attack_target = target
			mob.aim = actors[target].position
			continue
		move_monster(mob, actors[target].position, delta, float(stats[4]) * (1.0 + 0.08 * objective.pressure()))

func move_monster(mob: Dictionary, at: Vector3, delta: float, speed: float) -> void:
	var node: Node3D = mob.node
	var level = floors[mob.floor]
	var start := Acoustics.cell(node.position)
	var goal := Acoustics.cell(at)
	var next := next_cell(level.tiles, start, goal)
	var destination := Vector3(next.x * Dungeon.CELL, node.position.y, next.y * Dungeon.CELL)
	if start == goal:
		destination = Vector3(at.x, node.position.y, at.z)
	if next != start:
		var center := Vector3(start.x * Dungeon.CELL, node.position.y, start.y * Dungeon.CELL)
		var offset := destination - center
		if absf(offset.x) > 0.1 and absf(node.position.z - center.z) > 0.08:
			destination = Vector3(node.position.x, node.position.y, center.z)
		elif absf(offset.z) > 0.1 and absf(node.position.x - center.x) > 0.08:
			destination = Vector3(center.x, node.position.y, node.position.z)
	face_toward(mob, destination)
	var before := node.position
	node.position = node.position.move_toward(destination, delta * speed * (0.5 if mob.slow > 0 else 1.0))
	mob.step_distance += horizontal_distance(before, node.position)
	if mob.step_distance >= 1.5:
		mob.step_distance = fmod(mob.step_distance, 1.5)
		sound(mob.floor, node.position, 7.0, "enemy_step")

func idle_move(mob: Dictionary, delta: float) -> void:
	if mob.boss:
		return
	var node: Node3D = mob.node
	var speed: float = Bestiary.stats(mob.kind)[4] * 0.55
	if mob.investigate > 0:
		mob.investigate = maxf(0.0, mob.investigate - delta)
		if horizontal_distance(node.position, mob.heard_at) > 0.3:
			move_monster(mob, mob.heard_at, delta, speed * 1.35)
		else:
			mob.investigate = minf(mob.investigate, 1.5)
		mob.roam_goal = Acoustics.cell(node.position)
		mob.roam_wait = 1.0
		return
	var goal: Vector2i = mob.roam_goal
	var at := Vector3(goal.x * Dungeon.CELL, node.position.y, goal.y * Dungeon.CELL)
	if horizontal_distance(node.position, at) > 0.12:
		move_monster(mob, at, delta, speed)
		return
	mob.roam_wait -= delta
	if mob.roam_wait > 0:
		return
	var candidates: Array[Vector2i] = []
	var tiles: Dictionary = floors[mob.floor].tiles
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = goal + offset
		if tiles.has(cell):
			candidates.append(cell)
	if not candidates.is_empty():
		mob.roam_goal = candidates[awareness_rng.randi_range(0, candidates.size() - 1)]
	mob.roam_wait = awareness_rng.randf_range(0.6, 2.5)

func wake(mob: Dictionary) -> void:
	if mob.asleep:
		mob.asleep = false
		status_event(mob, "Awakened")
		var cue := "wake"
		match mob.kind:
			"brute": cue = "wake_ogre"
			"goblin", "jewel_hunter": cue = "wake_beast"
			"mage": cue = "wake_shade"
		sound(mob.floor, mob.node.position, 8.0, cue)

func emit_noise(floor_id: int, at: Vector3, radius: float) -> void:
	if radius <= 0 or not floors.has(floor_id):
		return
	var distances := Acoustics.reach(floors[floor_id].tiles, at, radius)
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != floor_id or mob.target != 0 or mob.boss:
			continue
		if Acoustics.audible(distances, at, mob.node.position, radius):
			wake(mob)
			mob.investigate = 8.0
			mob.heard_at = at
			face_toward(mob, at)

func player_noise(actor, radius: float, cue: String = "") -> void:
	radius *= maxf(0.1, 1.0 - actor.skills.bonus("noise")) * float(actor.Profiles.SPECIES[actor.species_id][5])
	actor.register_noise(radius)
	emit_noise(actor.floor_id, actor.position, radius)
	if cue != "":
		sound(actor.floor_id, actor.position, radius, cue)

func footsteps(actor, before: Vector3, delta: float) -> void:
	actor.decay_noise(delta)
	actor.step_distance += horizontal_distance(before, actor.position)
	if actor.step_distance >= 1.25:
		actor.step_distance = fmod(actor.step_distance, 1.25)
		var radius := Acoustics.QUIET if actor.quiet_walking else (Acoustics.SPRINT if actor.sprinting or actor.dash_timer > 0 else Acoustics.WALK)
		if actor.inventory.armor_index >= 0:
			radius *= Catalog.noise_multiplier(actor.inventory.items[actor.inventory.armor_index])
		player_noise(actor, radius, "quiet" if actor.quiet_walking else ("sprint" if actor.sprinting or actor.dash_timer > 0 else "step"))
		if actor.quiet_walking:
			credit_sneak(actor)

func credit_sneak(actor) -> void:
	var peer := str(actor.name)
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != actor.floor_id or mob.target != 0 or mob.boss or mob.reserve or mob.stealth_seen.has(peer):
			continue
		var distance := horizontal_distance(actor.position, mob.node.position)
		if distance >= 3.0 and distance <= 7.0 and Combat.clear_path(actor, mob.node.position):
			mob.stealth_seen[peer] = true
			actor.skills.credit(11, 3)

func awareness_name(mob: Dictionary) -> String:
	if mob.asleep:
		return "Asleep"
	if mob.target != 0:
		return "Engaged"
	if mob.investigate > 0:
		return "Investigating"
	return "Awake"

func status_summary(mob: Dictionary) -> String:
	var effects: PackedStringArray = []
	for key in ["burn", "bleed", "poison", "stun", "slow"]:
		if mob[key] > 0:
			effects.append({"burn": "Burning", "bleed": "Bleeding", "poison": "Poisoned", "stun": "Stunned", "slow": "Slowed"}[key])
	return "\n" + ", ".join(effects) if not effects.is_empty() else ""

func focused_enemy(actor, angle: float) -> Dictionary:
	var selected := {}
	var score := -1.0
	var forward := Vector2(-sin(angle), -cos(angle))
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != actor.floor_id:
			continue
		var offset := Vector2(mob.node.position.x - actor.position.x, mob.node.position.z - actor.position.z)
		var distance := offset.length()
		if distance > 18.0 or distance < 0.01:
			continue
		var alignment := offset.normalized().dot(forward)
		if alignment < 0.94 or not Combat.clear_path(actor, mob.node.position):
			continue
		var rank := alignment - distance * 0.005
		if rank > score:
			score = rank
			selected = mob
	return selected

func next_cell(tiles: Dictionary, start: Vector2i, goal: Vector2i) -> Vector2i:
	if start == goal or not tiles.has(start) or not tiles.has(goal):
		return start
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == goal:
			while parents[current] != start:
				current = parents[current]
			return current
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if tiles.has(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	return start

func monster_snapshot() -> Dictionary:
	var states := {}
	for id in monsters:
		var mob = monsters[id]
		states[id] = [mob.floor, mob.node.position, mob.health, mob.phase, mob.hurt, mob.stun, mob.bleed, mob.burn, mob.slow, mob.target, mob.poison, mob.asleep, mob.investigate, mob.threat.duplicate(), mob.node.rotation.y]
	return states

func apply_monsters(states: Dictionary) -> void:
	for id in states:
		if monsters.has(id):
			monsters[id].floor = states[id][0]
			monsters[id].node.position = states[id][1]
			monsters[id].health = states[id][2]
			monsters[id].phase = states[id][3]
			monsters[id].hurt = states[id][4]
			monsters[id].stun = states[id][5]
			monsters[id].bleed = states[id][6]
			monsters[id].burn = states[id][7]
			monsters[id].slow = states[id][8]
			monsters[id].target = states[id][9]
			monsters[id].poison = states[id][10]
			monsters[id].asleep = states[id][11]
			monsters[id].investigate = states[id][12]
			monsters[id].threat = states[id][13]
			monsters[id].node.rotation.y = states[id][14]

func strike(actor, party: Dictionary = {}) -> bool:
	if actor.health <= 0:
		return false
	var weapon = Catalog.get_item(actor.inventory.weapon)
	var radius: float = (Acoustics.BOW if weapon.projectile_speed > 0 else Acoustics.MELEE) * Catalog.noise_multiplier(actor.inventory.weapon)
	if weapon.projectile_speed > 0:
		if not actor.inventory.consume("arrows"):
			actor.empowered = ""
			return false
		player_noise(actor, radius, "bow")
		var source_peer = party.find_key(actor)
		var direction := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
		var effect := "arrow_poison" if actor.skills.learned.has("venom_arrow") else "arrow"
		projectiles.launch(actor.floor_id, actor.position, direction, weapon.projectile_speed, actor.attack_reach(), actor.attack_damage(), weapon.tint, 0 if source_peer == null else source_peer, false, effect, 10, actor.skills.bonus("pierce", 10))
		actor.empowered = ""
		return false
	var hits: Array = []
	var nearest = null
	var best: float = actor.attack_reach() + 1.0
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != actor.floor_id:
			continue
		if not Combat.can_hit(actor.position, mob.node.position, actor.heading, actor.attack_reach()) or not Combat.clear_path(actor, mob.node.position):
			continue
		hits.append(mob)
		var distance := horizontal_distance(actor.position, mob.node.position)
		if distance < best:
			nearest = mob
			best = distance
	if nearest == null:
		player_noise(actor, radius, "melee")
		journal.add("Combat", "%s misses" % actor.display_name, actor.floor_id, actor.position + Vector3.UP, "Miss", "status", int(actor.name) if str(actor.name).is_valid_int() else 0)
		actor.empowered = ""
		return false
	if actor.empowered != "cleave":
		hits = [nearest]
	for mob in hits:
		hit_monster(actor, mob, party)
	player_noise(actor, radius, "melee")
	actor.empowered = ""
	return true

func hit_monster(actor, mob: Dictionary, party: Dictionary) -> void:
	if mob.health <= 0:
		return
	var source_id = party.find_key(actor)
	var backstab: bool = actor.skills.bonus("backstab") > 0 and not mob.asleep and (mob.target == 0 or (source_id != null and mob.target != source_id)) and Vision.rear(mob.node.rotation.y, actor.position - mob.node.position)
	var ambush: bool = mob.target == 0 and mob.threat.is_empty() and not mob.boss and not mob.reserve and not mob.ambush_used and actor.skills.bonus("ambush") > 0
	mob.ambush_used = true
	wake(mob)
	var stats := Bestiary.stats(mob.kind)
	var domain: int = actor.skills.weapon_domain(actor.inventory.weapon)
	var damage: float = actor.attack_damage()
	if ambush:
		damage *= 1.0 + actor.skills.bonus("ambush")
		status_event(mob, "Ambush")
		actor.skills.credit(11, 8)
	if backstab:
		damage += actor.attack_damage() * actor.skills.bonus("backstab")
		status_event(mob, "Backstab")
		var key := str(source_id)
		if not mob.reserve and not mob.backstab_seen.has(key):
			mob.backstab_seen[key] = true
			actor.skills.credit(11, 5)
	if mob.health <= float(mob.get("max_health", stats[1])) * 0.3:
		damage *= 1.0 + actor.skills.bonus("execute")
	if mob.phase == 2:
		damage *= 1.0 + actor.skills.bonus("precision", domain)
	damage *= 1.0 - float(stats[7]) * (1.0 - actor.skills.bonus("pierce", domain))
	var peer = party.find_key(actor)
	if peer != null:
		Threat.add(mob, peer, minf(mob.health, damage) * (1.0 + actor.skills.bonus("threat")))
	sound(mob.floor, mob.node.position, 9.0, "impact")
	log_monster_hit(mob, actor.display_name, minf(mob.health, damage), "damage")
	mob.health = maxf(0.0, mob.health - damage)
	mob.hurt = 0.18
	actor.skills.credit(domain, 8)
	if mob.health <= 0:
		reward_kill(mob, actor, party)
		return
	var bleed: float = actor.skills.bonus("bleed", domain) + (actor.skills.bonus("ambush_bleed") if ambush else 0.0)
	if bleed > 0:
		if mob.bleed <= 0:
			status_event(mob, "Bleeding")
		mob.bleed = 4.0
		mob.bleed_damage = bleed
		var source_peer = party.find_key(actor)
		mob.bleed_owner = 0 if source_peer == null else source_peer
	mob.stun = maxf(mob.stun, actor.skills.bonus("stagger", domain))
	if Catalog.get_item(actor.inventory.weapon).poison > 0:
		if mob.poison <= 0:
			status_event(mob, "Poisoned")
		mob.poison = 5.0
		mob.poison_damage = Catalog.get_item(actor.inventory.weapon).poison
		mob.poison_owner = 0 if peer == null else peer
	if actor.empowered in ["impale", "bash"]:
		status_event(mob, "Stunned")
		mob.stun = maxf(mob.stun, 2.0)
		mob.phase = 0

func reward_kill(mob: Dictionary, killer, party: Dictionary) -> void:
	if mob.get("rewarded", false):
		return
	mob.rewarded = true
	flush_dots(mob)
	journal.add("Combat", "%s defeated%s" % [Bestiary.stats(mob.kind)[0], " by " + killer.display_name if killer != null else ""])
	mob.phase = 0
	mob.target = 0
	mob.threat.clear()
	mob.bleed = 0.0
	if mob.reserve:
		return
	if mob.boss:
		objective.boss_defeated(mob.kind)
		journal.add("Party", "Boss defeated: %s | Runes %d/2" % [Bestiary.stats(mob.kind)[0], objective.runes.size()])
	var reward: int = int(Bestiary.stats(mob.kind)[8]) + Routes.depth(mob.floor) * 25
	for teammate in party.values():
		if teammate == killer or teammate.health <= 0 or teammate.floor_id != mob.floor:
			continue
		if horizontal_distance(teammate.position, mob.node.position) <= 15.0:
			teammate.gain_xp(reward)
	if killer != null and killer.health > 0:
		killer.gain_xp(reward)
		killer.skills.credit(0, 10)
		killer.health = minf(killer.max_health(), killer.health + killer.skills.bonus("heal_kill"))
	var choices := ["potion", "potion", "noise_stone", "noise_stone", "axe", "spear", "iron_shield", "leather", "mail", "staff", "bow", "venom_dagger", "ward_mail", "scroll_firebolt", "scroll_frostbolt", "scroll_spark", "scroll_stonebolt", "iron_helm", "leather_gloves", "iron_boots", "ward_amulet", "ward_ring"]
	if mob.floor >= 1:
		choices.append_array(["longbow", "ember_staff", "scroll_fireball", "scroll_freeze", "scroll_thunder", "scroll_boulder"])
	var at: Vector3 = mob.node.position
	at.y = floors[mob.floor].position.y + 0.3
	var item_id: String = choices[loot_rng.randi_range(0, choices.size() - 1)]
	if mob.boss:
		item_id = Routes.REWARDS[mob.kind]
	elif loot_rng.randf() < 0.12:
		item_id = Catalog.enchant(item_id, loot_rng)
	if not mob.boss and mob.kind == "archer":
		loot.spawn("arrows", mob.floor, at, 12)
	else:
		loot.spawn(item_id, mob.floor, at)
		if not mob.boss and Catalog.get_item(item_id).projectile_speed > 0:
			loot.spawn("arrows", mob.floor, at + Vector3(0.35, 0, 0), 16)
	journal.add("Loot", "%s drops %s" % [Bestiary.stats(mob.kind)[0], "12 arrows" if not mob.boss and mob.kind == "archer" else Catalog.get_item(item_id).title])

func safe(actor) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "" or actor.combat_timer > 0:
		return false
	for mob in monsters.values():
		if mob.health > 0 and mob.floor == actor.floor_id and horizontal_distance(mob.node.position, actor.position) <= 12.0:
			return false
	return true

func discover(actor) -> bool:
	if actor.health <= 0 or actor.floor_id != 1 or horizontal_distance(actor.position, tablet_position) > 2.5 or actor.skills.discovered.has(secret_id):
		return false
	actor.skills.discovered.append(secret_id)
	return true

func cast(actor, source_peer: int, id: String) -> void:
	player_noise(actor, Acoustics.MAGIC, "magic")
	var stats := Spells.get_spell(id)
	var direction := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
	var damage: float = stats[2] * (1.0 + actor.skills.bonus("spell_damage", stats[0]) + Catalog.get_item(actor.inventory.weapon).spell_power)
	var bonus: float = actor.skills.bonus("burn_bonus", stats[0]) + actor.skills.bonus("slow_bonus", stats[0])
	projectiles.launch(actor.floor_id, actor.position, direction, stats[3], stats[4], damage, stats[6], source_peer, false, stats[7], stats[0], bonus)

func spell_hit(shot: Dictionary, mob: Dictionary, actors: Dictionary) -> void:
	if shot.effect == "blast":
		spell_blast(shot, mob.node.position, actors)
	else:
		apply_spell_damage(shot, mob, actors)

func spell_blast(shot: Dictionary, at: Vector3, actors: Dictionary) -> void:
	emit_noise(shot.floor, at, Acoustics.EXPLOSION)
	sound(shot.floor, at, Acoustics.EXPLOSION, "explosion")
	for mob in monsters.values():
		if mob.health > 0 and mob.floor == shot.floor and horizontal_distance(mob.node.position, at) <= 2.5:
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, mob.node.position, 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				apply_spell_damage(shot, mob, actors)

func apply_spell_damage(shot: Dictionary, mob: Dictionary, actors: Dictionary) -> void:
	if mob.health <= 0:
		return
	wake(mob)
	var caster = actors.get(shot.owner)
	var damage: float = shot.damage
	if shot.effect in ["burn", "blast"] and mob.slow > 0:
		damage *= 1.25
		mob.slow = 0.0
	if shot.effect in ["slow", "freeze"] and mob.burn > 0:
		damage *= 1.25
		mob.burn = 0.0
	if shot.effect.begins_with("arrow"):
		damage *= 1.0 - float(Bestiary.stats(mob.kind)[7]) * (1.0 - shot.bonus)
	else:
		damage *= 1.0 - Bestiary.resistance(mob.kind, shot.domain)
	Threat.add(mob, shot.owner, minf(mob.health, damage) * (1.0 + (caster.skills.bonus("threat") if caster != null else 0.0)))
	sound(mob.floor, mob.node.position, 9.0, "impact")
	log_monster_hit(mob, caster.display_name if caster != null else "Projectile", minf(mob.health, damage), "damage" if shot.effect.begins_with("arrow") else "magic")
	mob.health = maxf(0.0, mob.health - damage)
	mob.hurt = 0.18
	if caster != null and caster.health > 0:
		caster.skills.credit(shot.domain, 8)
	if mob.health <= 0:
		reward_kill(mob, caster, actors)
		return
	match shot.effect:
		"arrow_poison":
			if mob.poison <= 0:
				status_event(mob, "Poisoned")
			mob.poison = 5.0
			mob.poison_damage = 2.0
			mob.poison_owner = shot.owner
		"burn", "blast":
			if mob.burn <= 0:
				status_event(mob, "Burning")
			mob.burn = 4.0
			mob.burn_damage = 3.0 + shot.bonus
			mob.burn_owner = shot.owner
		"slow":
			if mob.slow <= 0:
				status_event(mob, "Slowed")
			mob.slow = 4.0 + shot.bonus
		"freeze":
			status_event(mob, "Frozen")
			mob.stun = maxf(mob.stun, 2.0)
			mob.phase = 0
		"shock", "stone":
			status_event(mob, "Staggered")
			mob.stun = maxf(mob.stun, 0.5)

static func encounter_count(floor_id: int, group_size: int) -> int:
	return ceili((6.0 + Routes.depth(floor_id) * 2.0) * (1.0 + 0.65 * (clampi(group_size, 1, 8) - 1)))

func threat_ability(actor, peer: int, ability: String) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "" or not actor.skills.learned.has(ability) or actor.skills.cooldowns.get(ability, 0.0) > 0:
		return false
	var changed := false
	if ability == "taunt":
		var chosen = null
		var best := 8.0
		for mob in monsters.values():
			if mob.health <= 0 or mob.floor != actor.floor_id:
				continue
			var distance := horizontal_distance(actor.position, mob.node.position)
			if distance <= best and Combat.can_hit(actor.position, mob.node.position, actor.heading, 8.0) and Combat.clear_path(actor, mob.node.position):
				chosen = mob
				best = distance
		if chosen != null:
			wake(chosen)
			Threat.taunt(chosen, peer)
			changed = true
	elif ability == "fade":
		for mob in monsters.values():
			if mob.health > 0 and mob.floor == actor.floor_id:
				if Threat.reduce(mob, peer):
					changed = true
	if changed:
		journal.add("Combat", "%s uses %s" % [actor.display_name, "Challenge" if ability == "taunt" else "Fade"])
		actor.combat_timer = 5.0
		actor.skills.cooldowns[ability] = 12.0 if ability == "taunt" else 20.0
	return changed

func branch_cell(level, rng: RandomNumberGenerator) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in level.rooms:
		if Vector2(cell).length() > 4.0 and Vector2(cell - level.end_cell).length() > 4.0:
			candidates.append(cell)
	if candidates.is_empty():
		for cell in level.tiles:
			if Vector2(cell).length() > 4.0 and Vector2(cell - level.end_cell).length() > 4.0:
				candidates.append(cell)
		candidates.sort()
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else Vector2i(2, 2)

func interact_objective(actor, peer: int) -> bool:
	if objective.result != "" or actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return false
	if actor.floor_id == 0 and horizontal_distance(actor.position, stair_position(0, false)) <= USE_RADIUS and objective.carrier == peer:
		if objective.escape(peer):
			journal.add("Party", "%s extracts the Jewel. Victory!" % actor.display_name)
			return true
		return false
	if objective.carrier != 0 or not objective.guardian_defeated or actor.floor_id != objective.jewel_floor or horizontal_distance(actor.position, objective.jewel_position) > USE_RADIUS:
		return false
	var first := not objective.started
	if not objective.claim(peer):
		return false
	journal.add("Party", "%s claims the Jewel" % actor.display_name)
	if first:
		for mob in monsters.values():
			if mob.reserve and not mob.rewarded:
				mob.health = mob.max_health
				mob.asleep = false
	return true

func release_jewel(actor, peer: int) -> bool:
	var at: Vector3 = actor.position
	at.y = floors[actor.floor_id].position.y
	if not objective.drop(peer, actor.floor_id, at):
		return false
	journal.add("Party", "%s drops the Jewel" % actor.display_name)
	return true

func update_objective(actors: Dictionary, delta: float) -> void:
	if objective.result != "":
		return
	for actor in actors.values():
		if actor.health <= 0:
			fail_party(actor.display_name)
			return
	if objective.started:
		objective.elapsed += delta

func objective_hint(actor, peer: int) -> String:
	if objective.carrier == peer and actor.floor_id == 0 and horizontal_distance(actor.position, stair_position(0, false)) <= USE_RADIUS:
		return "E: Escape with the Jewel"
	if objective.carrier == 0 and objective.guardian_defeated and actor.floor_id == objective.jewel_floor and horizontal_distance(actor.position, objective.jewel_position) <= USE_RADIUS:
		return "E: Take the Jewel"
	if objective.carrier == peer:
		return "G: Drop Jewel for teammate"
	return ""

func watch_player(actor, peer: int) -> void:
	actor.damage_event.connect(func(amount, blocked, parried, source_name): player_hit(actor, peer, amount, blocked, parried, source_name))
	actor.xp_event.connect(func(amount): journal.add("XP", "%s gains %d XP" % [actor.display_name, amount], actor.floor_id, actor.position + Vector3.UP, "+%d XP" % amount, "xp", peer))
	actor.skills.usage_xp.connect(func(domain, amount): journal.add("XP", "%s gains %s %s XP" % [actor.display_name, Numbers.number(amount), actor.Skills.TITLES[domain]]))

func player_hit(actor, peer: int, amount: float, blocked: bool, parried: bool, source_name: String) -> void:
	sound(actor.floor_id, actor.position, 9.0, "block" if blocked else "impact")
	var effect := "Parried" if parried else ("Blocked" if blocked else "")
	var number := "%0.1f" % amount if amount < 1.0 and amount > 0.0 else str(roundi(amount))
	var popup := effect if amount == 0 and effect != "" else ("-" + number + (" (" + effect + ")" if effect != "" else ""))
	journal.add("Combat", "%s hits %s for %s%s" % [source_name, actor.display_name, number, " (" + effect + ")" if effect != "" else ""], actor.floor_id, actor.position + Vector3.UP, popup, "blocked" if blocked else "incoming", peer)
	if actor.health <= 0:
		fail_party(actor.display_name)

func fail_party(player_name: String) -> void:
	if objective.result != "":
		return
	objective.result = "defeat"
	journal.add("Party", "%s has fallen. Expedition lost." % player_name)

func log_monster_hit(mob: Dictionary, source: String, amount: float, style: String) -> void:
	var number := str(roundi(amount)) if amount >= 1.0 else "%.1f" % amount
	var at: Vector3 = mob.node.position + Vector3.UP * (float(Bestiary.stats(mob.kind)[11]) * 0.5)
	journal.add("Combat", "%s hits %s for %s" % [source, Bestiary.stats(mob.kind)[0], number], mob.floor, at, number, style)

func status_event(mob: Dictionary, text: String) -> void:
	var at: Vector3 = mob.node.position + Vector3.UP * (float(Bestiary.stats(mob.kind)[11]) * 0.5)
	journal.add("Combat", "%s: %s" % [Bestiary.stats(mob.kind)[0], text], mob.floor, at, text, "status")

func record_dot(mob: Dictionary, source, effect: String, amount: float) -> void:
	var key := ("%s — %s" % [source.display_name if source != null else "Effect", effect])
	mob.dot_amount[key] = float(mob.dot_amount.get(key, 0.0)) + amount

func flush_dots(mob: Dictionary) -> void:
	for key in mob.dot_amount:
		log_monster_hit(mob, key, mob.dot_amount[key], "magic")
	mob.dot_amount.clear()
	mob.dot_time = 0.0

func throw_distraction(actor, index: int, peer: int) -> bool:
	if objective.result != "" or actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "" or index < 0 or index >= actor.inventory.items.size():
		return false
	if actor.inventory.items[index] != "noise_stone" or actor.inventory.remove(index) == "":
		return false
	var direction := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
	projectiles.launch(actor.floor_id, actor.position, direction, 12.0, 12.0, 0.0, Color("#b0b9c3"), peer, false, "distraction", 11, actor.skills.bonus("distraction"))
	journal.add("Loot", "%s throws a Noise Stone" % actor.display_name)
	return true

func distraction_lands(shot: Dictionary, at: Vector3) -> void:
	emit_noise(shot.floor, at, 14.0 * (1.0 + shot.bonus))
	sound(shot.floor, at, 14.0 * (1.0 + shot.bonus), "stone")
	journal.add("Combat", "Noise Stone lands", shot.floor, at, "Noise", "status")

func face_toward(mob: Dictionary, at: Vector3) -> void:
	var node: Node3D = mob.node
	var offset := at - node.position
	if Vector2(offset.x, offset.z).length_squared() > 0.0025:
		node.rotation.y = atan2(-offset.x, -offset.z)

func sound(floor_id: int, at: Vector3, radius: float, cue: String) -> void:
	if radius <= 0:
		return
	if sounds.size() >= 128:
		sounds.pop_front()
	sounds.append([floor_id, at, maxf(1.5, radius), cue])

func drain_sounds() -> Array:
	var events := sounds
	sounds = []
	return events

func voice_noise(actor, peer: int, radius: float) -> void:
	if objective.result != "" or actor.health <= 0 or radius <= 0.0:
		return
	radius = minf(radius, 18.0)
	actor.register_noise(radius)
	emit_noise(actor.floor_id, actor.position, radius)
	if radius < VoiceCodec.SHOUT_RADIUS:
		return
	var distances := Acoustics.reach(floors[actor.floor_id].tiles, actor.position, radius)
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != actor.floor_id or mob.target != 0 or not mob.threat.is_empty() or mob.boss:
			continue
		if Acoustics.audible(distances, actor.position, mob.node.position, radius):
			wake(mob)
			Threat.add(mob, peer, Threat.PULL)
			mob.target = peer
			mob.investigate = 0.0
			journal.add("Combat", "%s hears %s's shout" % [Bestiary.stats(mob.kind)[0], actor.display_name])

func voice_audible(speaker, listener, radius: float) -> bool:
	if speaker.floor_id != listener.floor_id or listener.health <= 0:
		return false
	var distances := Acoustics.reach(floors[speaker.floor_id].tiles, speaker.position, radius)
	return Acoustics.audible(distances, speaker.position, listener.position, radius)

func arrival_position(floor_id: int, center: Vector3, actors: Dictionary, arriving = null) -> Vector3:
	var level = floors[floor_id]
	var candidates: Array[Vector3] = []
	for z in range(-2, 3):
		for x in range(-2, 3):
			var offset := Vector3(x * 0.85, 0, z * 0.85)
			if offset.length() <= USE_RADIUS:
				candidates.append(center + offset + Vector3.UP)
	candidates.sort_custom(func(a: Vector3, b: Vector3):
		var da := a.distance_squared_to(center)
		var db := b.distance_squared_to(center)
		if not is_equal_approx(da, db):
			return da < db
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z)
	for at in candidates:
		var clear := true
		for x in [-0.36, 0.36]:
			for z in [-0.36, 0.36]:
				if not level.room_tiles.has(Acoustics.cell(at + Vector3(x, 0, z))):
					clear = false
		if not clear:
			continue
		for other in actors.values():
			if other != arriving and other.health > 0 and other.floor_id == floor_id and horizontal_distance(at, other.position) < 0.74:
				clear = false
				break
		if clear:
			return at
	return Vector3.INF

func follower_arrival(floor_id: int, arrival: Vector3, kind: String, index: int) -> Vector3:
	var stats := Bestiary.stats(kind)
	var clearance: float = float(stats[10]) + 0.12
	var at := arrival + Vector3(1.0 + float(index % 3) * 0.6, float(stats[11]) * 0.5, float(floori(float(index) / 3.0)) * 0.6)
	var cell := Acoustics.cell(arrival)
	for bounds in floors[floor_id].room_bounds:
		if not bounds.has_point(cell):
			continue
		at.x = clampf(at.x, (bounds.position.x - 0.5) * Dungeon.CELL + clearance, (bounds.end.x - 0.5) * Dungeon.CELL - clearance)
		at.z = clampf(at.z, (bounds.position.y - 0.5) * Dungeon.CELL + clearance, (bounds.end.y - 0.5) * Dungeon.CELL - clearance)
		break
	return at
