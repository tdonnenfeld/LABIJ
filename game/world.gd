extends Node3D

const Dungeon = preload("res://game/dungeon.gd")
const Combat = preload("res://game/combat.gd")
const Threat = preload("res://game/combat/threat.gd")
const Routes = preload("res://game/world/routes.gd")
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

func build(seed_value: int, render_geometry: bool, party_size: int = 1) -> void:
	visual = render_geometry
	hazards.visual = visual
	add_child(hazards)
	projectiles.visual = visual
	add_child(projectiles)
	loot.visual = visual
	add_child(loot)
	loot_rng.seed = seed_value + 53
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 97
	var secrets := ["forgotten", "stone", "ancient"]
	secret_id = secrets[rng.randi_range(0, 2)]
	for i in range(COUNT):
		var level := Dungeon.new()
		add_child(level)
		level.position.y = -i * SPACING
		level.generate(seed_value + i * 7919, visual, 5 if i >= Routes.MAIN_COUNT else 9)
		floors[i] = level
		if i == 1:
			tablet_position = level.position + Vector3(6, 0, 0)
			if visual:
				marker(level, Vector3(6, 0, 0), "ANCIENT TABLET [T]", Color("#8ab8a0"))
		for branch in Routes.PARENTS:
			if Routes.PARENTS[branch] == i:
				var entry: Vector2i = level.rooms[rng.randi_range(2, level.rooms.size() - 3)]
				branch_entries[branch] = level.position + Vector3(entry.x * Dungeon.CELL, 0, entry.y * Dungeon.CELL)
				if visual:
					marker(level, branch_entries[branch] - level.position, Routes.NAMES[branch] + " [E]", Color("#b98ddb"))
		if visual:
			if i > 0:
				marker(level, Vector3.ZERO, "RETURN [E]" if i >= Routes.MAIN_COUNT else "UP [E]", Color("#67a8de"))
			if i < Routes.MAIN_COUNT - 1:
				var end: Vector2i = level.end_cell
				marker(level, Vector3(end.x * Dungeon.CELL, 0, end.y * Dungeon.CELL), "DOWN [E]", Color("#d3ae55"))
		var cells: Array[Vector2i] = []
		for cell in level.tiles:
			if Vector2(cell).length() >= 7.0 and Vector2(cell - level.end_cell).length() >= 2.0 and not near_branch_entry(i, level.position + Vector3(cell.x * Dungeon.CELL, 0, cell.y * Dungeon.CELL)):
				cells.append(cell)
		cells.sort()
		var count := mini(cells.size(), encounter_count(i, party_size))
		if i >= Routes.MAIN_COUNT:
			count += 1
		for j in range(count):
			var pool: Array = Bestiary.ENCOUNTERS[i]
			var boss := i >= Routes.MAIN_COUNT and j == count - 1
			var kind: String = Routes.BOSSES[i] if boss else pool[rng.randi_range(0, pool.size() - 1)]
			var stats := Bestiary.stats(kind)
			var mob := Node3D.new()
			add_child(mob)
			var cell: Vector2i = level.end_cell
			if not boss:
				var pick := rng.randi_range(0, cells.size() - 1)
				cell = cells[pick]
				cells.remove_at(pick)
			mob.position = level.position + Vector3(cell.x * Dungeon.CELL, float(stats[11]) * 0.5, cell.y * Dungeon.CELL)
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
				var label := Label3D.new()
				label.text = stats[0]
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.position.y = float(stats[11]) * 0.5 + 0.3
				mob.add_child(label)
			monsters[i * 1000 + j] = {"node": mob, "kind": kind, "floor": i, "target": 0, "threat": {}, "health": float(stats[1]) * (1.0 + 0.35 * (clampi(party_size, 1, 8) - 1) if boss else 1.0), "boss": boss, "max_health": float(stats[1]) * (1.0 + 0.35 * (clampi(party_size, 1, 8) - 1) if boss else 1.0), "forced_target": 0, "force_timer": 0.0, "phase": 0, "timer": 0.0, "attack_target": 0, "aim": Vector3.ZERO, "hurt": 0.0, "bleed": 0.0, "bleed_damage": 0.0, "bleed_owner": 0, "stun": 0.0, "burn": 0.0, "burn_damage": 0.0, "burn_owner": 0, "slow": 0.0, "poison": 0.0, "poison_damage": 0.0, "poison_owner": 0}
		for j in range(mini(cells.size(), 2 + Routes.depth(i))):
			var pick := rng.randi_range(0, cells.size() - 1)
			var cell: Vector2i = cells[pick]
			cells.remove_at(pick)
			hazards.add_trap(i * 1000 + j, i, level.position + Vector3(cell.x * Dungeon.CELL, 0.06, cell.y * Dungeon.CELL), "spike" if rng.randf() < 0.5 else "fire")

func marker(level: Node3D, at: Vector3, caption: String, color: Color) -> void:
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
	var label := Label3D.new()
	label.text = caption
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3.UP * 1.5
	label.modulate = color
	level.add_child(label)

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
	loot.visible_floor(id)
	projectiles.visible_floor(id)
	for key in floors:
		floors[key].visible = key == id
	for mob in monsters.values():
		mob.node.visible = mob.floor == id and mob.health > 0
		if visual:
			var mesh: MeshInstance3D = mob.node.get_child(0)
			mesh.material_override.albedo_color = Color("#ffffff") if mob.hurt > 0 else (Color("#e5a64e") if mob.phase == 1 else (Color("#8aa7e0") if mob.stun > 0 or mob.slow > 0 else (Color("#e96c38") if mob.burn > 0 else Bestiary.stats(mob.kind)[9])))

func transfer(actor, peer_id: int) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return false
	var old: int = actor.floor_id
	var route := route_at(old, actor.position)
	if route.is_empty():
		return false
	var destination: int = route.destination
	var arrival: Vector3 = route.arrival
	var followers: Array = []
	for mob in monsters.values():
		if not mob.boss and mob.health > 0 and mob.floor == old and mob.target == peer_id and horizontal_distance(mob.node.position, actor.position) <= FOLLOW_RADIUS and horizontal_distance(mob.node.position, route.entry) <= FOLLOW_RADIUS:
			followers.append(mob)
	actor.floor_id = destination
	actor.position = arrival + Vector3(0, 1, 0)
	actor.velocity = Vector3.ZERO
	actor.direction = Vector2.ZERO
	for i in range(followers.size()):
		var mob = followers[i]
		mob.phase = 0
		mob.timer = 0.0
		mob.threat = {peer_id: maxf(Threat.PULL, mob.threat.get(peer_id, 0.0))}
		mob.force_timer = 0.0
		mob.floor = destination
		mob.node.position = arrival + Vector3(1.0 + float(i % 3) * 0.6, float(Bestiary.stats(mob.kind)[11]) * 0.5, float(i / 3) * 0.6)
	return true

func simulate(actors: Dictionary, delta: float) -> void:
	hazards.step(actors, delta)
	for mob in monsters.values():
		if mob.health <= 0:
			continue
		mob.hurt = maxf(0.0, mob.hurt - delta)
		mob.force_timer = maxf(0.0, mob.force_timer - delta)
		var stats := Bestiary.stats(mob.kind)
		mob.slow = maxf(0.0, mob.slow - delta)
		if mob.burn > 0:
			var burn_elapsed := minf(delta, mob.burn)
			mob.burn -= burn_elapsed
			Threat.add(mob, mob.burn_owner, minf(mob.health, mob.burn_damage * burn_elapsed))
			mob.health = maxf(0.0, mob.health - mob.burn_damage * burn_elapsed)
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.burn_owner), actors)
				continue
		if mob.bleed > 0:
			var elapsed := minf(delta, mob.bleed)
			mob.bleed -= elapsed
			Threat.add(mob, mob.bleed_owner, minf(mob.health, mob.bleed_damage * elapsed))
			mob.health = maxf(0.0, mob.health - mob.bleed_damage * elapsed)
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.bleed_owner), actors)
				continue
		if mob.poison > 0:
			var elapsed := minf(delta, mob.poison)
			mob.poison -= elapsed
			var damage := minf(mob.health, mob.poison_damage * elapsed)
			Threat.add(mob, mob.poison_owner, damage)
			mob.health -= damage
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.poison_owner), actors)
				continue
		if mob.stun > 0:
			mob.stun = maxf(0.0, mob.stun - delta)
			continue
		var node: Node3D = mob.node
		var closest := 12.0
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
			if distance < closest and Combat.clear_path(node, actor.position):
				closest = distance
				seen = id
		var target := Threat.choose(mob, eligible, distances)
		if target == 0 and seen != 0:
			Threat.add(mob, seen, Threat.PULL)
			target = seen
		mob.target = target
		if target != 0:
			closest = distances[target]
		if mob.phase != 0:
			mob.timer -= delta
			if mob.timer <= 0:
				if mob.phase == 1:
					var victim = actors.get(mob.attack_target)
					if mob.kind == "crypt_warden":
						for actor in actors.values():
							if actor.health > 0 and actor.floor_id == mob.floor and horizontal_distance(actor.position, node.position) <= 3.2 and Combat.clear_path(node, actor.position):
								actor.take_damage(float(stats[2]), node.position)
					elif mob.kind == "ember_oracle":
						var direction: Vector3 = mob.aim - node.position
						for angle in [-0.24, 0.0, 0.24]:
							projectiles.launch(mob.floor, node.position, direction.rotated(Vector3.UP, angle), 10.0, float(stats[3]), float(stats[2]), Color("#ef864b"), 0, true, "hex", -1)
					elif mob.kind in ["archer", "mage"]:
						var direction: Vector3 = mob.aim - node.position
						projectiles.launch(mob.floor, node.position, direction, 14.0 if mob.kind == "archer" else 9.0, float(stats[3]), float(stats[2]), Color("#d8c7a0") if mob.kind == "archer" else Color("#cf73e8"), 0, true, "hex" if mob.kind == "mage" else "", -1)
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= float(stats[3]) and Combat.clear_path(node, victim.position):
						victim.take_damage(float(stats[2]), node.position)
					elif victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= 4.0:
						victim.skills.credit(5, 4)
					mob.phase = 2
					mob.timer = float(stats[6])
				else:
					mob.phase = 0
			continue
		if target == 0:
			continue
		if closest <= float(stats[3]) and Combat.clear_path(node, actors[target].position):
			mob.phase = 1
			mob.timer = float(stats[5])
			mob.attack_target = target
			mob.aim = actors[target].position
			continue
		var level = floors[mob.floor]
		var start := Vector2i(roundi(node.position.x / Dungeon.CELL), roundi(node.position.z / Dungeon.CELL))
		var goal := Vector2i(roundi(actors[target].position.x / Dungeon.CELL), roundi(actors[target].position.z / Dungeon.CELL))
		var next := next_cell(level.tiles, start, goal)
		var destination := Vector3(next.x * Dungeon.CELL, node.position.y, next.y * Dungeon.CELL)
		if start == goal:
			destination = Vector3(actors[target].position.x, node.position.y, actors[target].position.z)
		# Move toward tile centers before turning so walls are not crossed.
		if next != start and horizontal_distance(node.position, Vector3(start.x * Dungeon.CELL, node.position.y, start.y * Dungeon.CELL)) > 0.08:
			var center := Vector3(start.x * Dungeon.CELL, node.position.y, start.y * Dungeon.CELL)
			var offset := destination - center
			if absf(offset.x) > 0.1 and absf(node.position.z - center.z) > 0.08:
				destination = Vector3(node.position.x, node.position.y, center.z)
			elif absf(offset.z) > 0.1 and absf(node.position.x - center.x) > 0.08:
				destination = Vector3(center.x, node.position.y, node.position.z)
		node.position = node.position.move_toward(destination, delta * float(stats[4]) * (0.5 if mob.slow > 0 else 1.0))

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
		states[id] = [mob.floor, mob.node.position, mob.health, mob.phase, mob.hurt, mob.stun, mob.bleed, mob.burn, mob.slow, mob.target, mob.poison]
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

func strike(actor, party: Dictionary = {}) -> bool:
	if actor.health <= 0:
		return false
	var weapon = Catalog.get_item(actor.inventory.weapon)
	if weapon.projectile_speed > 0:
		var owner = party.find_key(actor)
		var direction := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
		var effect := "arrow_poison" if actor.skills.learned.has("venom_arrow") else "arrow"
		projectiles.launch(actor.floor_id, actor.position, direction, weapon.projectile_speed, actor.attack_reach(), actor.attack_damage(), weapon.tint, 0 if owner == null else owner, false, effect, 10, actor.skills.bonus("pierce", 10))
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
		actor.empowered = ""
		return false
	if actor.empowered != "cleave":
		hits = [nearest]
	for mob in hits:
		hit_monster(actor, mob, party)
	actor.empowered = ""
	return true

func hit_monster(actor, mob: Dictionary, party: Dictionary) -> void:
	var stats := Bestiary.stats(mob.kind)
	var domain: int = actor.skills.weapon_domain(actor.inventory.weapon)
	var damage: float = actor.attack_damage()
	if mob.health <= float(mob.get("max_health", stats[1])) * 0.3:
		damage *= 1.0 + actor.skills.bonus("execute")
	if mob.phase == 2:
		damage *= 1.0 + actor.skills.bonus("precision", domain)
	damage *= 1.0 - float(stats[7]) * (1.0 - actor.skills.bonus("pierce", domain))
	var peer = party.find_key(actor)
	if peer != null:
		Threat.add(mob, peer, minf(mob.health, damage) * (1.0 + actor.skills.bonus("threat")))
	mob.health = maxf(0.0, mob.health - damage)
	mob.hurt = 0.18
	actor.skills.credit(domain, 8)
	if mob.health <= 0:
		reward_kill(mob, actor, party)
		return
	var bleed: float = actor.skills.bonus("bleed", domain)
	if bleed > 0:
		mob.bleed = 4.0
		mob.bleed_damage = bleed
		var owner = party.find_key(actor)
		mob.bleed_owner = 0 if owner == null else owner
	mob.stun = maxf(mob.stun, actor.skills.bonus("stagger", domain))
	if Catalog.get_item(actor.inventory.weapon).poison > 0:
		mob.poison = 5.0
		mob.poison_damage = Catalog.get_item(actor.inventory.weapon).poison
		mob.poison_owner = 0 if peer == null else peer
	if actor.empowered in ["impale", "bash"]:
		mob.stun = maxf(mob.stun, 2.0)
		mob.phase = 0

func reward_kill(mob: Dictionary, killer, party: Dictionary) -> void:
	mob.phase = 0
	mob.target = 0
	mob.threat.clear()
	mob.bleed = 0.0
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
	var choices := ["potion", "potion", "axe", "spear", "iron_shield", "leather", "mail", "staff", "bow", "venom_dagger", "ward_mail", "scroll_firebolt", "scroll_frostbolt", "scroll_spark", "scroll_stonebolt"]
	if mob.floor >= 1:
		choices.append_array(["longbow", "ember_staff", "scroll_fireball", "scroll_freeze", "scroll_thunder", "scroll_boulder"])
	var at: Vector3 = mob.node.position
	at.y = floors[mob.floor].position.y + 0.3
	var item_id: String = choices[loot_rng.randi_range(0, choices.size() - 1)]
	if mob.boss:
		item_id = Routes.REWARDS[mob.kind]
	elif loot_rng.randf() < 0.12:
		item_id = Catalog.enchant(item_id, loot_rng)
	loot.spawn(item_id, mob.floor, at)

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

func cast(actor, owner: int, id: String) -> void:
	var stats := Spells.get_spell(id)
	var direction := Vector3(-sin(actor.heading), 0, -cos(actor.heading))
	var damage: float = stats[2] * (1.0 + actor.skills.bonus("spell_damage", stats[0]) + Catalog.get_item(actor.inventory.weapon).spell_power)
	var bonus: float = actor.skills.bonus("burn_bonus", stats[0]) + actor.skills.bonus("slow_bonus", stats[0])
	projectiles.launch(actor.floor_id, actor.position, direction, stats[3], stats[4], damage, stats[6], owner, false, stats[7], stats[0], bonus)

func spell_hit(shot: Dictionary, mob: Dictionary, actors: Dictionary) -> void:
	if shot.effect == "blast":
		spell_blast(shot, mob.node.position, actors)
	else:
		apply_spell_damage(shot, mob, actors)

func spell_blast(shot: Dictionary, at: Vector3, actors: Dictionary) -> void:
	for mob in monsters.values():
		if mob.health > 0 and mob.floor == shot.floor and horizontal_distance(mob.node.position, at) <= 2.5:
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, mob.node.position, 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				apply_spell_damage(shot, mob, actors)

func apply_spell_damage(shot: Dictionary, mob: Dictionary, actors: Dictionary) -> void:
	var owner = actors.get(shot.owner)
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
	Threat.add(mob, shot.owner, minf(mob.health, damage) * (1.0 + (owner.skills.bonus("threat") if owner != null else 0.0)))
	mob.health = maxf(0.0, mob.health - damage)
	mob.hurt = 0.18
	if owner != null and owner.health > 0:
		owner.skills.credit(shot.domain, 8)
	if mob.health <= 0:
		reward_kill(mob, owner, actors)
		return
	match shot.effect:
		"arrow_poison":
			mob.poison = 5.0
			mob.poison_damage = 2.0
			mob.poison_owner = shot.owner
		"burn", "blast":
			mob.burn = 4.0
			mob.burn_damage = 3.0 + shot.bonus
			mob.burn_owner = shot.owner
		"slow":
			mob.slow = 4.0 + shot.bonus
		"freeze":
			mob.stun = maxf(mob.stun, 2.0)
			mob.phase = 0
		"shock", "stone":
			mob.stun = maxf(mob.stun, 0.5)

static func encounter_count(floor_id: int, party_size: int) -> int:
	return ceili((6.0 + Routes.depth(floor_id) * 2.0) * (1.0 + 0.65 * (clampi(party_size, 1, 8) - 1)))

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
			Threat.taunt(chosen, peer)
			changed = true
	elif ability == "fade":
		for mob in monsters.values():
			if mob.health > 0 and mob.floor == actor.floor_id:
				if Threat.reduce(mob, peer):
					changed = true
	if changed:
		actor.combat_timer = 5.0
		actor.skills.cooldowns[ability] = 12.0 if ability == "taunt" else 20.0
	return changed
