extends Node3D

const Dungeon = preload("res://game/dungeon.gd")
const Combat = preload("res://game/combat.gd")
const Bestiary = preload("res://game/monsters/bestiary.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Loot = preload("res://game/items/loot.gd")
var loot := Loot.new()
var loot_rng := RandomNumberGenerator.new()
var shrine_position := Vector3.ZERO
var tablet_position := Vector3.ZERO
var secret_id := ""
const COUNT := 4
const SPACING := 30.0
const USE_RADIUS := 2.5
const FOLLOW_RADIUS := 3.0
var floors: Dictionary = {}
var monsters: Dictionary = {}
var visual := false

func build(seed_value: int, render_geometry: bool) -> void:
	visual = render_geometry
	loot.visual = visual
	add_child(loot)
	loot_rng.seed = seed_value + 53
	var secrets := ["forgotten", "stone", "ancient"]
	secret_id = secrets[randi_range(0, 2)]
	for i in range(COUNT):
		var level := Dungeon.new()
		add_child(level)
		level.position.y = -i * SPACING
		level.generate(seed_value + i * 7919, visual)
		floors[i] = level
		if i == 2:
			shrine_position = level.position + Vector3(6, 0, 0)
			if visual:
				marker(level, Vector3(6, 0, 0), "RESPEC SHRINE [K]", Color("#ae8ed8"))
		if i == 1:
			tablet_position = level.position + Vector3(6, 0, 0)
			if visual:
				marker(level, Vector3(6, 0, 0), "ANCIENT TABLET [T]", Color("#8ab8a0"))
		if visual:
			if i > 0:
				marker(level, Vector3.ZERO, "UP [E]", Color("#67a8de"))
			if i < COUNT - 1:
				var end: Vector2i = level.end_cell
				marker(level, Vector3(end.x * Dungeon.CELL, 0, end.y * Dungeon.CELL), "DOWN [E]", Color("#d3ae55"))
		for j in range(Bestiary.ENCOUNTERS[i].size()):
			var kind: String = Bestiary.ENCOUNTERS[i][j]
			var stats := Bestiary.stats(kind)
			var mob := Node3D.new()
			add_child(mob)
			var cell: Vector2i = level.end_cell - Vector2i(j % 3 + 1, floori(float(j) / 3.0))
			if not level.tiles.has(cell):
				cell = level.end_cell
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
			monsters[i * 10 + j] = {"node": mob, "kind": kind, "floor": i, "target": 0, "health": float(stats[1]), "phase": 0, "timer": 0.0, "attack_target": 0, "aim": Vector3.ZERO, "hurt": 0.0, "bleed": 0.0, "bleed_damage": 0.0, "bleed_owner": 0, "stun": 0.0}

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

func stair_at(id: int, at: Vector3) -> int:
	if id > 0 and horizontal_distance(at, stair_position(id, false)) <= USE_RADIUS:
		return -1
	if id < COUNT - 1 and horizontal_distance(at, stair_position(id, true)) <= USE_RADIUS:
		return 1
	return 0

func visible_floor(id: int) -> void:
	loot.visible_floor(id)
	for key in floors:
		floors[key].visible = key == id
	for mob in monsters.values():
		mob.node.visible = mob.floor == id and mob.health > 0
		if visual:
			var mesh: MeshInstance3D = mob.node.get_child(0)
			mesh.material_override.albedo_color = Color("#ffffff") if mob.hurt > 0 else (Color("#e5a64e") if mob.phase == 1 else (Color("#8aa7e0") if mob.stun > 0 else Bestiary.stats(mob.kind)[9]))

func transfer(actor, peer_id: int) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0:
		return false
	var old: int = actor.floor_id
	var step := stair_at(old, actor.position)
	if step == 0:
		return false
	var destination := old + step
	var arrival := stair_position(destination, step < 0)
	var followers: Array = []
	for mob in monsters.values():
		if mob.health > 0 and mob.floor == old and mob.target == peer_id and horizontal_distance(mob.node.position, actor.position) <= FOLLOW_RADIUS and horizontal_distance(mob.node.position, stair_position(old, step > 0)) <= FOLLOW_RADIUS:
			followers.append(mob)
	actor.floor_id = destination
	actor.position = arrival + Vector3(0, 1, 0)
	actor.velocity = Vector3.ZERO
	actor.direction = Vector2.ZERO
	for i in range(followers.size()):
		var mob = followers[i]
		mob.phase = 0
		mob.timer = 0.0
		mob.floor = destination
		mob.node.position = arrival + Vector3(1.0 + float(i % 3) * 0.6, float(Bestiary.stats(mob.kind)[11]) * 0.5, float(i / 3) * 0.6)
	return true

func simulate(actors: Dictionary, delta: float) -> void:
	for mob in monsters.values():
		if mob.health <= 0:
			continue
		mob.hurt = maxf(0.0, mob.hurt - delta)
		var stats := Bestiary.stats(mob.kind)
		if mob.bleed > 0:
			var elapsed := minf(delta, mob.bleed)
			mob.bleed -= elapsed
			mob.health = maxf(0.0, mob.health - mob.bleed_damage * elapsed)
			if mob.health <= 0:
				reward_kill(mob, actors.get(mob.bleed_owner), actors)
				continue
		if mob.stun > 0:
			mob.stun = maxf(0.0, mob.stun - delta)
			continue
		var node: Node3D = mob.node
		var closest := 12.0
		var target := 0
		for id in actors:
			var actor = actors[id]
			if actor.floor_id != mob.floor or actor.health <= 0:
				continue
			var distance := horizontal_distance(actor.position, node.position)
			if distance < closest:
				closest = distance
				target = id
		mob.target = target
		if mob.phase != 0:
			mob.timer -= delta
			if mob.timer <= 0:
				if mob.phase == 1:
					var victim = actors.get(mob.attack_target)
					if victim != null and victim.health > 0 and victim.floor_id == mob.floor and horizontal_distance(victim.position, node.position) <= float(stats[3]) and Combat.clear_path(node, victim.position) and (mob.kind != "archer" or horizontal_distance(victim.position, mob.aim) <= 1.2):
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
		node.position = node.position.move_toward(destination, delta * float(stats[4]))

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
		states[id] = [mob.floor, mob.node.position, mob.health, mob.phase, mob.hurt, mob.stun, mob.bleed]
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

func strike(actor, party: Dictionary = {}) -> bool:
	if actor.health <= 0:
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
	if mob.health <= float(stats[1]) * 0.3:
		damage *= 1.0 + actor.skills.bonus("execute")
	if mob.phase == 2:
		damage *= 1.0 + actor.skills.bonus("precision", domain)
	damage *= 1.0 - float(stats[7]) * (1.0 - actor.skills.bonus("pierce", domain))
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
	if actor.empowered in ["impale", "bash"]:
		mob.stun = maxf(mob.stun, 2.0)
		mob.phase = 0

func reward_kill(mob: Dictionary, killer, party: Dictionary) -> void:
	mob.phase = 0
	mob.target = 0
	mob.bleed = 0.0
	var reward: int = int(Bestiary.stats(mob.kind)[8]) + mob.floor * 25
	for teammate in party.values():
		if teammate == killer or teammate.health <= 0 or teammate.floor_id != mob.floor:
			continue
		if horizontal_distance(teammate.position, mob.node.position) <= 15.0:
			teammate.gain_xp(reward)
	if killer != null and killer.health > 0:
		killer.gain_xp(reward)
		killer.skills.credit(0, 10)
		killer.health = minf(killer.max_health(), killer.health + killer.skills.bonus("heal_kill"))
	var choices := ["potion", "potion", "axe", "spear", "iron_shield"]
	var at: Vector3 = mob.node.position
	at.y = floors[mob.floor].position.y + 0.3
	loot.spawn(choices[loot_rng.randi_range(0, choices.size() - 1)], mob.floor, at)

func safe(actor) -> bool:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.combat_timer > 0:
		return false
	for mob in monsters.values():
		if mob.health > 0 and mob.floor == actor.floor_id and horizontal_distance(mob.node.position, actor.position) <= 12.0:
			return false
	return true

func near_shrine(actor) -> bool:
	return actor.floor_id == 2 and horizontal_distance(actor.position, shrine_position) <= 2.5

func discover(actor) -> bool:
	if actor.health <= 0 or actor.floor_id != 1 or horizontal_distance(actor.position, tablet_position) > 2.5 or actor.skills.discovered.has(secret_id):
		return false
	actor.skills.discovered.append(secret_id)
	return true
