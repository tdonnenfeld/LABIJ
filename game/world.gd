extends Node3D

const ActorRig = preload("res://game/visuals/actor_rig.gd")
const NetMotion = preload("res://game/network/net_motion.gd")
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
var escape_entries: Dictionary = {}
var escape_labels: Dictionary = {}
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
var fixtures: Dictionary = {}
var floor_keys: Dictionary = {}

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
		level.generate(seed_value + i * 7919, visual, room_count, i >= Routes.MAIN_COUNT, i, true)
		level.hide()
		floors[i] = level
		if i in [2, 3, Routes.SANCTUARY] and not level.side_rooms.is_empty():
			var cell: Vector2i = level.side_rooms[0]
			var at := Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)
			escape_entries[i] = level.position + at
			if visual:
				escape_labels[i] = marker(level, at, "SEALED ESCAPE SHAFT", Color("#c6aa79"))
		if i == 1:
			tablet_position = level.position + Vector3(3, 0, 0)
			if visual:
				marker(level, Vector3(3, 0, 0), "ANCIENT TABLET [T]", Color("#8ab8a0"))
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
		if level.rooms.size() > 3:
			for n in range(1, mini(4, level.rooms.size() - 1)):
				var cell: Vector2i = level.rooms[n]
				var at := level.position + Vector3(cell.x * Dungeon.CELL + 1.0, 0.0, cell.y * Dungeon.CELL + 1.0)
				if near_branch_entry(i, at) or (escape_entries.has(i) and horizontal_distance(at, escape_entries[i]) < 3.0):
					continue
				add_fixture(i * 10 + n, i, at, ["chest", "crate", "inscription"][n - 1])
		if not level.doors.is_empty():
			add_fixture(10000 + i * 10, i, level.position + Vector3(0.9, 0, 0.9), "key")
			if level.rooms.size() > 3:
				var room: Vector2i = level.rooms[1]
				add_fixture(10001 + i * 10, i, level.position + Vector3(room.x * Dungeon.CELL - 1.0, 0, room.y * Dungeon.CELL - 1.0), "lever")
		if i == Routes.SANCTUARY:
			objective.jewel_position = stair_position(i, true)
		var cells: Array[Vector2i] = []
		for cell in level.room_tiles:
			if (not escape_entries.has(i) or horizontal_distance(level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL), escape_entries[i]) >= 4.0) and Vector2(cell).length() >= 4.0 and Vector2(cell - level.end_cell).length() >= 2.0 and not near_branch_entry(i, level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)):
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
	var mob := CharacterBody3D.new()
	mob.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	mob.collision_layer = 0 if reserve else 4
	mob.collision_mask = 0 if reserve else 7
	add_child(mob)
	var hp: float = float(stats[1]) * (1.0 + 0.35 * (clampi(group_size, 1, 8) - 1) if boss else 1.0)
	mob.position = at + Vector3.UP * float(stats[11]) * 0.5
	mob.rotation.y = float(id % 16) * TAU / 16.0
	if visual:
		var rig := ActorRig.new()
		rig.name = "ActorRig"
		mob.add_child(rig)
		rig.kind = kind
		rig.height = float(stats[11])
		rig.ever_alive = not reserve
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

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = stats[10]
	capsule.height = stats[11]
	collision.shape = capsule
	mob.add_child(collision)
	monsters[id] = {"node": mob, "kind": kind, "floor": floor_id, "target": 0, "threat": {}, "health": 0.0 if reserve else hp, "boss": boss, "reserve": reserve, "rewarded": false, "max_health": hp, "forced_target": 0, "force_timer": 0.0, "phase": 0, "timer": 0.0, "attack_target": 0, "aim": Vector3.ZERO, "hurt": 0.0, "bleed": 0.0, "bleed_damage": 0.0, "bleed_owner": 0, "stun": 0.0, "burn": 0.0, "burn_damage": 0.0, "burn_owner": 0, "slow": 0.0, "poison": 0.0, "poison_damage": 0.0, "poison_owner": 0, "dot_amount": {}, "dot_time": 0.0, "asleep": not boss and not reserve and awareness_rng.randf() < 0.45, "investigate": 0.0, "heard_at": at, "roam_goal": Acoustics.cell(at), "roam_wait": awareness_rng.randf_range(0.5, 3.0), "stealth_seen": {}, "ambush_used": false, "backstab_seen": {}, "step_distance": 0.0, "move_speed": 0.0, "moved_last": false, "path_key": [], "path_next": Vector2i.ZERO, "home": Acoustics.cell(at), "alerted": false, "rage_phase": false}
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
	if escape_entries.has(id) and horizontal_distance(at, escape_entries[id]) <= USE_RADIUS:
		if not objective.started:
			return {"locked": true, "label": "Sealed escape shaft", "step": 0}
		var upper := 3 if id == Routes.SANCTUARY else id - 1
		return {"destination": upper, "arrival": stair_position(upper, false), "entry": escape_entries[id], "label": "Escape shaft", "step": -1}
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
	for label in escape_labels.values():
		label.text = "ESCAPE SHAFT [E]" if objective.started else "SEALED ESCAPE SHAFT"
	projectiles.visible_floor(id)
	for key in floors:
		floors[key].visible = key == id
		if key == id:
			floors[key].ensure_visuals()
	for mob in monsters.values():
		var rig = mob.node.get_node_or_null("ActorRig")
		var alive: bool = mob.health > 0
		if rig:
			rig.ever_alive = rig.ever_alive or alive
		mob.node.visible = mob.floor == id and (alive or (rig != null and rig.ever_alive))
		if visual and mob.node.visible:
			if rig and not rig.model:
				rig.setup(mob.kind, float(Bestiary.stats(mob.kind)[11]))
			var label: Label3D = mob.node.get_child(1)
			label.visible = alive
			var filled := clampi(ceili(10.0 * mob.health / mob.max_health), 0, 10)
			label.text = "%s — %s\n%s%s %d/%d%s" % [Bestiary.stats(mob.kind)[0], awareness_name(mob), "█".repeat(filled), "░".repeat(10 - filled), ceili(mob.health), ceili(mob.max_health), status_summary(mob)]
			label.modulate = Color("#f1c879") if mob.phase == 1 else (Color("#e9a1a1") if mob.hurt > 0 else Color.WHITE)
			if mob.kind in ["crypt_warden", "jewel_sentinel"]:
				mob.node.get_child(2).visible = alive and mob.phase == 1 and mob.stun <= 0

func animate_monsters(delta: float) -> void:
	if not visual:
		return
	projectiles.animate_visuals()
	for mob in monsters.values():
		if not mob.node.visible:
			continue
		var rig = mob.node.get_node_or_null("ActorRig")
		if rig:
			var stats := Bestiary.stats(mob.kind)
			var duration: float = float(stats[5] if mob.phase == 1 else stats[6])
			rig.animate(delta, mob.health > 0, mob.phase, mob.asleep, mob.hurt > 0, false, false, float(mob.get("hit_direction", 0.0)), clampf(1.0 - float(mob.timer) / duration, 0.0, 1.0))


func transfer(actor, peer_id: int, actors: Dictionary = {}) -> bool:
	if objective.result != "" or actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return false
	if interact_objective(actor, peer_id):
		return true
	if revive_companion(actor, actors):
		return true
	var old: int = actor.floor_id
	if discover_secret(actor):
		return true
	var route := route_at(old, actor.position)
	if route.is_empty():
		if interact_door(actor, actors) or disarm_trap(actor):
			return true
		return interact_fixture(actor)
	if route.get("locked", false):
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
	var occupied_actors := actors.duplicate()
	occupied_actors[peer_id] = actor
	for i in range(followers.size()):
		var mob = followers[i]
		var stats := Bestiary.stats(mob.kind)
		var landing_mob := free_landing(destination, arrival, occupied_actors, float(stats[10]), float(stats[11]) * 0.5, null, mob.node)
		if landing_mob == Vector3.INF:
			continue
		mob.phase = 0
		mob.timer = 0.0
		mob.threat = {peer_id: maxf(Threat.PULL, mob.threat.get(peer_id, 0.0))}
		mob.force_timer = 0.0
		mob.floor = destination
		mob.asleep = false
		mob.investigate = 0.0
		mob.roam_goal = Acoustics.cell(arrival)
		mob.node.position = landing_mob
	return true

func simulate(actors: Dictionary, delta: float) -> void:
	if objective.result != "":
		return
	hazards.step(actors, delta)
	for mob in monsters.values():
		set_monster_collision(mob)
	var occupied := {}
	for actor in actors.values():
		if actor.health > 0:
			occupied[actor.floor_id] = true
	for mob in monsters.values():
		if objective.result != "":
			break
		if mob.health <= 0:
			continue
		if not mob.moved_last:
			mob.move_speed = move_toward(mob.move_speed, 0.0, delta * 9.0)
		mob.moved_last = false
		mob.dot_time += delta
		mob.hurt = maxf(0.0, mob.hurt - delta)
		mob.force_timer = maxf(0.0, mob.force_timer - delta)
		var stats := Bestiary.stats(mob.kind)
		var tactics := Bestiary.tactics(mob.kind)
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
		if target != 0 and not mob.alerted and mob.kind in ["goblin", "guardian", "jewel_hunter"]:
			mob.alerted = true
			for ally in monsters.values():
				if ally != mob and ally.floor == mob.floor and ally.health > 0 and horizontal_distance(ally.node.position, node.position) <= 7.0 and Combat.clear_path(node, ally.node.position):
					wake(ally)
					Threat.add(ally, target, Threat.PULL * 0.5)
			journal.add("Combat", "%s calls for help" % stats[0])
		if mob.boss and not mob.rage_phase and mob.health <= mob.max_health * 0.5:
			mob.rage_phase = true
			journal.add("Combat", "%s enters its final phase" % stats[0])
		mob.target = target
		if target != 0:
			closest = distances[target]
		if mob.phase != 0:
			if mob.phase == 1 or (mob.phase == 2 and float(tactics[2]) > 0.0):
				var moving_target = actors.get(mob.attack_target)
				if moving_target != null and moving_target.health > 0 and moving_target.floor_id == mob.floor:
					if mob.phase == 1 and float(tactics[2]) == 0.0 and horizontal_distance(node.position, moving_target.position) > float(stats[3]) * 0.65:
						move_monster(mob, moving_target.position, delta, float(stats[4]) * float(tactics[1]))
					elif float(tactics[2]) > 0.0 and horizontal_distance(node.position, moving_target.position) < float(tactics[2]):
						retreat_monster(mob, moving_target.position, delta, float(stats[4]) * float(tactics[1]))
					face_toward(mob, moving_target.position, delta)
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
						for angle in ([-0.48, -0.24, 0.0, 0.24, 0.48] if mob.rage_phase else [-0.24, 0.0, 0.24]):
							projectiles.launch(mob.floor, node.position, direction.rotated(Vector3.UP, angle), 10.0, float(stats[3]), float(stats[2]), Color("#ef864b"), 0, true, "hex", -1)
					elif mob.kind in ["archer", "mage"]:
						var direction: Vector3 = mob.aim - node.position
						projectiles.launch(mob.floor, node.position, direction, 14.0 if mob.kind == "archer" else 9.0, float(stats[3]), float(stats[2]), Color("#d8c7a0") if mob.kind == "archer" else Color("#cf73e8"), 0, true, "hex" if mob.kind == "mage" else "", -1)
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= float(stats[3]) and Combat.clear_path(node, victim.position):
						guarded_hit(victim, float(stats[2]), node.position, stats[0], actors)
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= 4.0:
						victim.skills.credit(5, 4)
						journal.add("Combat", "%s dodges %s" % [victim.display_name, stats[0]], victim.floor_id, victim.position + Vector3.UP, "Dodged", "blocked", int(victim.name) if str(victim.name).is_valid_int() else 0)
					mob.phase = 2
					mob.timer = float(stats[6]) * (0.72 if mob.rage_phase else 1.0)
				else:
					mob.phase = 0
			continue
		if target == 0:
			if not mob.asleep and occupied.has(mob.floor):
				idle_move(mob, delta)
			continue
		if mob.kind in ["archer", "mage"] and closest < 3.0 and mob.health < mob.max_health * 0.5:
			retreat_monster(mob, actors[target].position, delta, float(stats[4]))
			continue
		if closest <= float(stats[3]) + float(tactics[0]) and Combat.clear_path(node, actors[target].position):
			face_toward(mob, actors[target].position)
			mob.move_speed = 0.0
			mob.phase = 1
			mob.timer = float(stats[5]) * (0.82 if mob.rage_phase else 1.0)
			mob.attack_target = target
			mob.aim = actors[target].position
			if mob.kind in ["goblin", "guardian", "jewel_hunter"]:
				emit_noise(mob.floor, node.position, 6.0)
			continue
		move_monster(mob, actors[target].position, delta, float(stats[4]) * (1.0 + 0.08 * objective.pressure()))

func retreat_monster(mob: Dictionary, target: Vector3, delta: float, speed: float) -> void:
	var node: CharacterBody3D = mob.node
	var away := node.position - target
	away.y = 0.0
	if away.length_squared() > 0.01:
		node.move_and_collide(away.normalized() * speed * delta, false, 0.001)

func move_monster(mob: Dictionary, at: Vector3, delta: float, speed: float) -> void:
	var node: CharacterBody3D = mob.node
	var level = floors[mob.floor]
	var start := Acoustics.cell(node.position)
	var goal := Acoustics.cell(at)
	var key: Array = [mob.floor, start, goal, level.secret_open]
	if mob.path_key != key:
		mob.path_key = key
		mob.path_next = next_cell(level.tiles, start, goal)
	var next: Vector2i = mob.path_next
	if mob.kind != "rat":
		var door = level.doors.get(next, level.doors.get(start))
		if door and not door.opened and not door.locked and horizontal_distance(node.global_position, door.global_position) <= 1.2:
			door.set_open(true)
			sound(mob.floor, door.global_position, 5.0, "impact")
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
	face_toward(mob, destination, delta)
	mob.moved_last = true
	var before := node.position
	var target_speed := speed * (0.5 if mob.slow > 0 else 1.0)
	var remaining := horizontal_distance(node.position, destination)
	target_speed *= clampf(remaining / 0.45, 0.25, 1.0)
	var acceleration := 5.0 if mob.kind in ["brute", "guardian", "crypt_warden", "jewel_sentinel"] else 12.0
	mob.move_speed = move_toward(mob.move_speed, target_speed, delta * acceleration)
	var motion := (destination - node.position).limit_length(delta * float(mob.move_speed))
	var hit := node.move_and_collide(motion, false, 0.001)
	if hit:
		# Queue at a choke, but slide along other bodies when space permits.
		var tangent := hit.get_remainder().slide(hit.get_normal())
		tangent.y = 0.0
		if tangent.length_squared() > 0.000001:
			node.move_and_collide(tangent, false, 0.001)

	if motion.length_squared() > 0.0001 and horizontal_distance(before, node.position) < motion.length() * 0.2:
		mob.move_speed = move_toward(mob.move_speed, 0.0, delta * 4.0)
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
		if tiles.has(cell) and Vector2(cell - Vector2i(mob.home)).length() <= 3.0:
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
		player_noise(actor, radius, "quiet" if actor.quiet_walking else ("sprint" if actor.sprinting or actor.dash_timer > 0 else ("step_mail" if actor.inventory.armor_index >= 0 and actor.inventory.items[actor.inventory.armor_index] in ["mail", "ward_mail"] else "step")))
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
		states[id] = [mob.floor, mob.node.position, mob.health, mob.phase, mob.hurt, mob.stun, mob.bleed, mob.burn, mob.slow, mob.target, mob.poison, mob.asleep, mob.investigate, mob.threat.duplicate(), mob.node.rotation.y, mob.get("hit_direction", 0.0), mob.timer]
	return states

func apply_monsters(states: Dictionary, smooth: bool = false) -> void:
	for id in states:
		if monsters.has(id):
			var mob: Dictionary = monsters[id]
			if smooth:
				NetMotion.receive(mob.node, states[id][1], states[id][14], mob.floor != states[id][0] or mob.health <= 0 or states[id][2] <= 0)
			else:
				NetMotion.reset(mob.node)
				mob.node.position = states[id][1]
				mob.node.rotation.y = states[id][14]
			monsters[id].floor = states[id][0]
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
			if states[id].size() > 15:
				mob.hit_direction = states[id][15]
			if states[id].size() > 16:
				mob.timer = states[id][16]
			set_monster_collision(monsters[id])

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
		var direction := Combat.aim_direction(actor.heading, actor.look_pitch)
		var effect := "arrow_poison" if actor.skills.learned.has("venom_arrow") else "arrow"
		projectiles.launch(actor.floor_id, Combat.shot_origin(actor), direction, weapon.projectile_speed * lerpf(0.45, 1.0, actor.shot_power), actor.attack_reach() * lerpf(0.5, 1.0, actor.shot_power), actor.attack_damage() * lerpf(0.4, 1.0, actor.shot_power), weapon.tint, 0 if source_peer == null else source_peer, false, effect, 10, actor.skills.bonus("pierce", 10))
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
		if break_door(actor) or break_fixture(actor):
			player_noise(actor, radius, "impact")
			actor.empowered = ""
			return true
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
	if mob.stun > 0.0 and mob.slow > 0.0 and domain in [2, 3]:
		damage *= 1.3
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
	mob.hit_direction = hit_side(mob, actor.position)
	if mob.stun > 0.0 and mob.slow > 0.0 and domain in [2, 3]:
		status_event(mob, "Shattered")
		mob.slow = 0.0
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
	set_monster_collision(mob)
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
			journal.add("XP", "%s assists: +%d XP" % [teammate.display_name, reward])
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

func cast(actor, source_peer: int, id: String, party: Dictionary = {}) -> void:
	player_noise(actor, Acoustics.MAGIC, "magic")
	var stats := Spells.get_spell(id)
	var direction := Combat.aim_direction(actor.heading, actor.look_pitch)
	var damage: float = stats[2] * (1.0 + actor.skills.bonus("spell_damage", stats[0]) + Catalog.get_item(actor.inventory.weapon).spell_power)
	var bonus: float = actor.skills.bonus("burn_bonus", stats[0]) + actor.skills.bonus("slow_bonus", stats[0])
	if id == "spark" and actor.selected_spell == id:
		cast_beam(actor, source_peer, direction, damage * 0.25, stats[4], party)
	else:
		projectiles.launch(actor.floor_id, Combat.shot_origin(actor), direction, stats[3], stats[4], damage, stats[6], source_peer, false, stats[7], stats[0], bonus)

func spell_hit(shot: Dictionary, mob: Dictionary, actors: Dictionary) -> void:
	if shot.effect == "blast":
		spell_blast(shot, mob.node.position, actors)
	elif shot.effect == "chain":
		apply_spell_damage(shot, mob, actors)
		var visited: Array = [mob]
		var source: Node3D = mob.node
		var damage: float = shot.damage
		for hop in range(2):
			var nearest: Dictionary = {}
			var best := 4.0
			for candidate in monsters.values():
				if candidate in visited or candidate.health <= 0 or candidate.floor != shot.floor:
					continue
				var distance: float = source.position.distance_to(candidate.node.position)
				if distance < best and Combat.clear_path(source, candidate.node.position):
					best = distance
					nearest = candidate
			if nearest.is_empty():
				break
			damage *= 0.65
			var jump := shot.duplicate()
			jump.damage = damage
			journal.add("Combat", "Lightning arcs", shot.floor, nearest.node.position, "", "lightning", 0, source.position)
			apply_spell_damage(jump, nearest, actors)
			visited.append(nearest)
			source = nearest.node
	else:
		apply_spell_damage(shot, mob, actors)

func spell_blast(shot: Dictionary, at: Vector3, actors: Dictionary) -> void:
	for entry in fixtures.values():
		if not entry.used and entry.kind == "crate" and entry.floor == shot.floor and entry.at.distance_to(at) <= 2.5:
			var ray := PhysicsRayQueryParameters3D.create(at, entry.at + Vector3.UP * 0.4, 1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				destroy_crate(entry)
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
	if caster != null:
		mob.hit_direction = hit_side(mob, caster.position)
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
			mob.slow = maxf(mob.slow, 2.0)
			mob.phase = 0
		"shock", "chain", "stone":
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
				set_monster_collision(mob)
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
	var living := 0
	for actor in actors.values():
		if actor.health > 0:
			living += 1
	if living == 0 and not actors.is_empty():
		fail_party("The party")
		return
	if objective.started:
		objective.elapsed += delta

func objective_hint(actor, peer: int) -> String:
	if objective.carrier == peer and actor.floor_id == 0 and horizontal_distance(actor.position, stair_position(0, false)) <= USE_RADIUS:
		return "E: Escape with the Jewel"
	if objective.carrier == 0 and objective.guardian_defeated and actor.floor_id == objective.jewel_floor and horizontal_distance(actor.position, objective.jewel_position) <= USE_RADIUS:
		return "E: Take the Jewel"
	var door = floors[actor.floor_id].nearby_door(actor.global_position)
	if door and not door.broken:
		if door.locked:
			return "E: Unlock door | Attack: Break wood"
		return "E: Close door" if door.opened else "E: Open door"
	for fixture in fixtures.values():
		if not fixture.used and fixture.floor == actor.floor_id and horizontal_distance(actor.position, fixture.at) <= 1.7:
			return {"crate":"Attack: Break crate", "chest":"E: Open chest", "key":"E: Take floor key", "lever":"E: Pull lever", "inscription":"E: Read inscription"}.get(fixture.kind, "E: Interact")
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
	journal.add("Combat", "%s hits %s for %s%s" % [source_name, actor.display_name, number, " (" + effect + ")" if effect != "" else ""], actor.floor_id, actor.position + Vector3.UP, popup, "blocked" if blocked else "incoming", peer, actor.last_damage_source)
	if actor.health <= 0:
		release_jewel(actor, peer)
		journal.add("Party", "%s is downed — a companion can revive them" % actor.display_name)

func revive_companion(actor, actors: Dictionary) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "" or not safe(actor):
		return false
	for other in actors.values():
		if other == actor or other.health > 0 or other.floor_id != actor.floor_id:
			continue
		if horizontal_distance(actor.position, other.position) > 2.0 or not Combat.clear_path(actor, other.position):
			continue
		var center: Vector3 = other.position
		center.y = floors[other.floor_id].position.y
		var landing := arrival_position(other.floor_id, center, actors, other)
		if landing == Vector3.INF:
			continue
		other.position = landing
		other.health = other.max_health() * 0.3
		other.stamina = 30.0
		other.velocity = Vector3.ZERO
		other.direction = Vector2.ZERO
		other.collision_layer = 2
		other.collision_mask = 7
		journal.add("Party", "%s revives %s" % [actor.display_name, other.display_name])
		sound(actor.floor_id, actor.position, 4.0, "potion")
		return true
	return false

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
	var direction := Combat.aim_direction(actor.heading, actor.look_pitch)
	projectiles.launch(actor.floor_id, actor.position, direction, 12.0, 12.0, 0.0, Color("#b0b9c3"), peer, false, "distraction", 11, actor.skills.bonus("distraction"))
	journal.add("Loot", "%s throws a Noise Stone" % actor.display_name)
	return true

func distraction_lands(shot: Dictionary, at: Vector3) -> void:
	emit_noise(shot.floor, at, 14.0 * (1.0 + shot.bonus))
	sound(shot.floor, at, 14.0 * (1.0 + shot.bonus), "stone")
	journal.add("Combat", "Noise Stone lands", shot.floor, at, "Noise", "status")

func face_toward(mob: Dictionary, at: Vector3, delta: float = 0.0) -> void:
	var node: Node3D = mob.node
	var offset := at - node.position
	if Vector2(offset.x, offset.z).length_squared() > 0.0025:
		var target := atan2(-offset.x, -offset.z)
		node.rotation.y = lerp_angle(node.rotation.y, target, minf(1.0, delta * 9.0)) if delta > 0.0 else target

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
	return free_landing(floor_id, center, actors, 0.32, 1.0, arriving)

func free_landing(floor_id: int, center: Vector3, actors: Dictionary, radius: float, height: float, arriving = null, ignored_mob = null) -> Vector3:
	var level = floors[floor_id]
	var candidates: Array[Vector3] = []
	for z in range(-2, 3):
		for x in range(-2, 3):
			var offset := Vector3(x * 0.85, 0, z * 0.85)
			if offset.length() <= USE_RADIUS:
				candidates.append(center + offset + Vector3.UP * height)
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
		for x in [-radius - 0.12, radius + 0.12]:
			for z in [-radius - 0.12, radius + 0.12]:
				if not level.room_tiles.has(Acoustics.cell(at + Vector3(x, 0, z))):
					clear = false
		if not clear:
			continue
		for other in actors.values():
			if other != arriving and other.health > 0 and other.floor_id == floor_id and horizontal_distance(at, other.position) < radius + 0.32 + 0.10:
				clear = false
				break
		if clear:
			for mob in monsters.values():
				if mob.node != ignored_mob and mob.floor == floor_id and mob.health > 0 and horizontal_distance(at, mob.node.position) < radius + float(Bestiary.stats(mob.kind)[10]) + 0.10:
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

func set_monster_collision(mob: Dictionary) -> void:
	var alive: bool = mob.health > 0.0
	mob.node.collision_layer = 4 if alive else 0
	mob.node.collision_mask = 7 if alive else 0

func secret_near(actor) -> bool:
	var level = floors[actor.floor_id]
	if level.secret_open or level.hidden_tiles.is_empty():
		return false
	var normal := Vector3(level.secret_direction.x, 0, level.secret_direction.y)
	var offset: Vector3 = actor.position - level.secret_position()
	return horizontal_distance(actor.position, level.secret_position()) <= 1.7 and offset.dot(normal) <= 0.0

func discover_secret(actor) -> bool:
	if not secret_near(actor):
		return false
	var level = floors[actor.floor_id]
	if not level.reveal_secret():
		return false
	var cell: Vector2i = level.hidden_room
	var at: Vector3 = level.position + Vector3(cell.x * Dungeon.CELL, 0.3, cell.y * Dungeon.CELL)
	loot.spawn("ward_ring" if actor.floor_id < 2 else "ward_amulet", actor.floor_id, at)
	loot.spawn("potion", actor.floor_id, at + Vector3(0.65, 0, 0), 3)
	journal.add("Loot", "%s discovers a hidden chamber" % actor.display_name)
	return true

func secret_state() -> Array:
	var result: Array = []
	for id in floors:
		if floors[id].secret_open:
			result.append(id)
		for cell in floors[id].doors:
			var door = floors[id].doors[cell]
			result.append(["door", id, cell, door.opened])
			result.append(["door_detail", id, cell, door.locked, door.trapped, door.broken, door.durability])
		if floor_keys.get(id, false):
			result.append(["key", id])
	for id in fixtures:
		if fixtures[id].used:
			result.append(["fixture", id])
	return result

func apply_secrets(data: Array) -> void:
	for id in data:
		if id is Array:
			if id.size() == 4 and id[0] == "door" and floors.has(id[1]) and floors[id[1]].doors.has(id[2]):
				floors[id[1]].doors[id[2]].set_open(bool(id[3]))
			elif id.size() == 7 and id[0] == "door_detail" and floors.has(id[1]) and floors[id[1]].doors.has(id[2]):
				var door = floors[id[1]].doors[id[2]]
				door.locked = bool(id[3])
				door.trapped = bool(id[4])
				door.broken = bool(id[5])
				door.durability = float(id[6])
				if door.broken:
					door.set_open(true)
			elif id.size() == 2 and id[0] == "key":
				floor_keys[id[1]] = true
			elif id.size() == 2 and id[0] == "fixture" and fixtures.has(id[1]):
				mark_fixture_used(fixtures[id[1]])
		elif floors.has(id):
			floors[id].reveal_secret()

func advance_network_motion(delta: float) -> void:
	for mob in monsters.values():
		if mob.health > 0:
			NetMotion.advance(mob.node, delta)
	projectiles.advance_network_motion(delta)

func add_fixture(id: int, floor_id: int, at: Vector3, kind: String) -> void:
	var entry := {"floor": floor_id, "at": at, "kind": kind, "used": false, "node": null}
	fixtures[id] = entry
	if not visual:
		return
	var prop := Node3D.new()
	floors[floor_id].add_child(prop)
	prop.position = at - floors[floor_id].position
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.75, 0.5, 0.48) if kind != "inscription" else Vector3(0.48, 0.9, 0.26)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#8a653b") if kind != "inscription" else Color("#8b9292")
	mesh.material_override = mat
	prop.add_child(mesh)
	mesh.position.y = box.size.y * 0.5
	var labels := {"chest":"CHEST [E]", "crate":"CRATE", "inscription":"INSCRIPTION [E]", "key":"FLOOR KEY [E]", "lever":"GATE LEVER [E]"}
	marker(prop, Vector3.ZERO, labels.get(kind, kind.to_upper()), Color("#d3ae76"))
	entry.node = prop

func mark_fixture_used(entry: Dictionary) -> void:
	entry.used = true
	if is_instance_valid(entry.node):
		entry.node.hide()

func interact_fixture(actor) -> bool:
	for entry in fixtures.values():
		if entry.used or entry.kind == "crate" or entry.floor != actor.floor_id or horizontal_distance(actor.position, entry.at) > 1.7:
			continue
		if not Combat.clear_path(actor, entry.at + Vector3.UP * 0.5):
			continue
		mark_fixture_used(entry)
		if entry.kind == "key":
			floor_keys[entry.floor] = true
			journal.add("Exploration", "Party found the floor key")
			return true
		if entry.kind == "lever":
			for door in floors[entry.floor].doors.values():
				if door.style == "iron":
					door.locked = false
					door.set_open(true)
			journal.add("Exploration", "The floor portcullises rise")
			return true
		if entry.kind == "chest":
			loot.spawn("potion", entry.floor, entry.at + Vector3.UP * 0.3)
			journal.add("Loot", "%s opens a forgotten chest" % actor.display_name)
			sound(entry.floor, entry.at, 4.0, "pickup")
		else:
			var lore := ["The gaoler hid the keys beneath the stones.", "The drowned chapel remembers its last prayer.", "The wardens sealed the Jewel with two runes."]
			journal.add("Exploration", lore[entry.floor % lore.size()])
		return true
	return false

func break_fixture(actor) -> bool:
	for entry in fixtures.values():
		if entry.used or entry.kind != "crate" or entry.floor != actor.floor_id:
			continue
		if not Combat.can_hit(actor.position, entry.at + Vector3.UP * 0.5, actor.heading, actor.attack_reach()) or not Combat.clear_path(actor, entry.at + Vector3.UP * 0.5):
			continue
		mark_fixture_used(entry)
		loot.spawn("noise_stone", entry.floor, entry.at + Vector3.UP * 0.3, 2)
		journal.add("Loot", "%s breaks a supply crate" % actor.display_name)
		return true
	return false

func hit_side(mob: Dictionary, source: Vector3) -> float:
	var node: Node3D = mob.node
	var offset := source - node.position
	return clampf(node.global_basis.x.dot(offset.normalized()), -1.0, 1.0)

func recover_arrow(floor_id: int, at: Vector3) -> void:
	var level = floors[floor_id]
	var cell := Acoustics.cell(at)
	if not level.tiles.has(cell):
		return
	var landing := Vector3(at.x, level.position.y + 0.3, at.z)
	loot.spawn("arrows", floor_id, landing, 1)

func destroy_crate(entry: Dictionary) -> void:
	if entry.used:
		return
	mark_fixture_used(entry)
	loot.spawn("noise_stone", entry.floor, entry.at + Vector3.UP * 0.3, 2)
	journal.add("Exploration", "A supply crate breaks")
	sound(entry.floor, entry.at, 5.0, "impact")

func projectile_fixture_hit(floor_id: int, from: Vector3, to: Vector3, limit: float) -> float:
	var closest: Dictionary = {}
	var best := limit
	for entry in fixtures.values():
		if entry.used or entry.kind != "crate" or entry.floor != floor_id:
			continue
		var t := Projectiles.segment_hit(from, to, entry.at + Vector3.UP * 0.25, 0.45)
		if t >= 0.0 and t < best:
			closest = entry
			best = t
	if closest.is_empty():
		return -1.0
	destroy_crate(closest)
	return best

func cast_beam(actor, peer: int, direction: Vector3, damage: float, reach: float, party: Dictionary) -> void:
	var from := Combat.shot_origin(actor)
	var to := from + direction * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	var limit := 1.0 if wall.is_empty() else from.distance_to(wall.position) / reach
	var target: Dictionary = {}
	for mob in monsters.values():
		if mob.health <= 0 or mob.floor != actor.floor_id:
			continue
		var radius := maxf(0.45, float(Bestiary.stats(mob.kind)[11]) * 0.5)
		var t := Projectiles.segment_hit(from, to, mob.node.position, radius)
		if t >= 0.0 and t < limit:
			limit = t
			target = mob
	journal.add("Combat", "Lightning beam", actor.floor_id, from.lerp(to, limit), "", "lightning", 0, from)
	if projectile_fixture_hit(actor.floor_id, from, to, limit) >= 0.0:
		return
	if not target.is_empty():
		apply_spell_damage({"owner": peer, "damage": damage, "effect": "shock", "domain": 8, "bonus": 0.0}, target, party if not party.is_empty() else {peer: actor})

func interact_door(actor, actors: Dictionary) -> bool:
	var door = floors[actor.floor_id].nearby_door(actor.global_position)
	if not door or door.broken:
		return false
	var direction: Vector3 = door.global_position - actor.global_position
	direction.y = 0.0
	var forward := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
	if direction.length() > 0.3 and forward.dot(direction.normalized()) < 0.15:
		return false
	if door.locked:
		if floor_keys.get(actor.floor_id, false) or actor.skills.bonus("lockpick") > 0:
			door.locked = false
			if actor.skills.bonus("lockpick") > 0:
				actor.skills.credit(11, 10)
		else:
			journal.add("Exploration", "Locked: find the floor key or use Lockpicking.")
			return true
	if door.trapped and not door.opened:
		door.trapped = false
		if actor.skills.bonus("disarm") > 0:
			actor.skills.credit(11, 8)
			journal.add("Exploration", "Door trap disarmed")
		else:
			actor.take_damage(15.0, door.global_position, false, "Door trap")
			if actor.health <= 0:
				return true
	if door.opened:
		if door.obstructed(actor.global_position):
			return false
		for other in actors.values():
			if other.floor_id == actor.floor_id and door.obstructed(other.global_position):
				return false
		for mob in monsters.values():
			if mob.floor == actor.floor_id and mob.health > 0 and door.obstructed(mob.node.global_position):
				return false
	door.set_open(not door.opened)
	sound(actor.floor_id, door.global_position, 5.0, "impact")
	emit_noise(actor.floor_id, door.global_position, 5.0)
	journal.add("Exploration", "%s %s a door" % [actor.display_name, "opens" if door.opened else "closes"])
	return true

func break_door(actor) -> bool:
	if not floors.has(actor.floor_id):
		return false
	var door = floors[actor.floor_id].nearby_door(actor.global_position, actor.attack_reach() + 0.3)
	if not door or not Combat.can_hit(actor.position, door.global_position + Vector3.UP, actor.heading, actor.attack_reach()):
		return false
	if not door.damage(actor.attack_damage()):
		return false
	emit_noise(actor.floor_id, door.global_position, 12.0)
	if door.broken:
		journal.add("Exploration", "Wooden door shattered")
	return true

func disarm_trap(actor) -> bool:
	if actor.skills.bonus("disarm") <= 0:
		return false
	for trap in hazards.traps.values():
		if trap.floor == actor.floor_id and trap.phase < 2 and horizontal_distance(actor.position, trap.node.position) <= 1.8:
			trap.phase = 2
			actor.skills.credit(11, 10)
			journal.add("Exploration", "Pressure plate disarmed")
			return true
	return false

func guarded_hit(victim, damage: float, source: Vector3, source_name: String, actors: Dictionary) -> void:
	var guard = null
	var reduction := 0.0
	for ally in actors.values():
		if ally == victim or ally.health <= 0 or ally.floor_id != victim.floor_id or not ally.blocking:
			continue
		if horizontal_distance(ally.position, victim.position) > 2.0 or not Combat.facing(ally.heading, source - ally.position):
			continue
		var bonus: float = ally.skills.bonus("bodyguard")
		if bonus > reduction and ally.stamina >= 5.0:
			guard = ally
			reduction = bonus
	if guard != null:
		guard.stamina -= 5.0
		guard.skills.credit(4, 4)
		journal.add("Party", "%s protects %s" % [guard.display_name, victim.display_name])
	victim.take_damage(damage * (1.0 - reduction), source, false, source_name)
