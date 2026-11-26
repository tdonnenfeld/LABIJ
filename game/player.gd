extends CharacterBody3D

const Combat = preload("res://game/combat.gd")
const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
var inventory := Inventory.new()
const Skills = preload("res://game/progression/skills.gd")
const Spells = preload("res://game/combat/spells.gd")
var mana := 100.0
var wants_sprint := false
var sprinting := false
var sprint_exhausted := false
var cast_id := ""
var cast_timer := 0.0
var skills := Skills.new()
var combat_timer := 0.0
var fortify_timer := 0.0
var dash_timer := 0.0
var escape_timer := 0.0
var last_block := 0.0
var block_age := 1.0
var empowered := ""
var empower_timer := 0.0

var health := Combat.MAX_HEALTH
var stamina := Combat.MAX_STAMINA
var blocking := false
var wants_block := false
var attack_phase := 0
var attack_timer := 0.0
var hurt_timer := 0.0
var swing_hit := false
var sword: MeshInstance3D
var shield: MeshInstance3D
var floor_id := 0
var direction := Vector2.ZERO
var heading := 0.0
var look_pitch := 0.0
var camera: Camera3D

func setup(local: bool, visual: bool = true) -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collision.shape = capsule
	add_child(collision)
	if not visual:
		return
	var mesh := MeshInstance3D.new()
	var model := CapsuleMesh.new()
	model.radius = 0.32
	model.height = 1.7
	mesh.mesh = model
	mesh.visible = not local
	add_child(mesh)
	if local:
		camera = Camera3D.new()
		camera.position.y = 0.55
		camera.current = true
		add_child(camera)
		var light := OmniLight3D.new()
		light.omni_range = 14
		light.light_energy = 2.5
		camera.add_child(light)
		sword = hand_item(Vector3(0.42, -0.36, -0.85), Vector3(0.10, 0.75, 0.10), Color("#bcb8a9"))
		shield = hand_item(Vector3(-0.48, -0.38, -0.8), Vector3(0.40, 0.52, 0.12), Color("#78604a"))

func simulate(delta: float) -> void:
	if health <= 0.0:
		sprinting = false
		velocity = Vector3.ZERO
		return
	rotation.y = heading
	update_sprint(delta)
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(cos(heading), 0, -sin(heading))
	var motion := (right * direction.x + forward * direction.y) * (2.5 if blocking or attack_phase == 1 else 4.5) * (1.0 + skills.bonus("move")) * (2.0 if dash_timer > 0 else (1.55 if sprinting else 1.0))
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = maxf(velocity.y - 18.0 * delta, -20.0)
	move_and_slide()

func hand_item(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	item.material_override = mat
	camera.add_child(item)
	item.position = at
	return item

func begin_attack() -> bool:
	var weapon = Catalog.get_item(inventory.weapon)
	if health <= 0 or attack_phase != 0 or cast_id != "" or blocking or stamina < attack_cost():
		return false
	sprinting = false
	stamina -= attack_cost()
	attack_phase = 1
	attack_timer = weapon.windup * attack_speed_factor()
	swing_hit = false
	combat_timer = 5.0
	return true

func advance_combat(delta: float) -> bool:
	hurt_timer = maxf(0.0, hurt_timer - delta)
	combat_timer = maxf(0.0, combat_timer - delta)
	fortify_timer = maxf(0.0, fortify_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	escape_timer = maxf(0.0, escape_timer - delta)
	last_block = maxf(0.0, last_block - delta)
	empower_timer = maxf(0.0, empower_timer - delta)
	if empower_timer == 0 and attack_phase == 0:
		empowered = ""
	for id in skills.cooldowns.keys():
		skills.cooldowns[id] = maxf(0.0, skills.cooldowns[id] - delta)
	if health <= 0:
		return false
	var was_blocking := blocking
	blocking = wants_block and attack_phase == 0 and cast_id == "" and stamina > 0
	if blocking:
		block_age = block_age + delta if was_blocking else 0.0
	mana = minf(100.0, mana + delta * 5.0)
	if not blocking and not sprinting and attack_phase == 0 and cast_id == "":
		stamina = minf(Combat.MAX_STAMINA, stamina + delta * (18.0 + skills.bonus("regen")))
	if attack_phase == 0:
		return false
	attack_timer -= delta
	if attack_timer > 0:
		return false
	if attack_phase == 1:
		attack_phase = 2
		attack_timer = Catalog.get_item(inventory.weapon).recovery * attack_speed_factor()
		return true
	attack_phase = 0
	return false

func take_damage(amount: float, source: Vector3) -> void:
	if health <= 0:
		return
	if blocking and stamina >= block_cost() and Combat.facing(heading, source - position):
		stamina -= block_cost()
		amount *= 1.0 - minf(0.95, Catalog.get_item(inventory.shield).reduction + skills.bonus("reduction"))
		skills.credit(4, 5)
		last_block = 3.0
		stamina = minf(Combat.MAX_STAMINA, stamina + skills.bonus("block_restore"))
		if skills.bonus("parry") > 0 and block_age <= 0.25:
			amount = 0.0
	combat_timer = 5.0
	amount *= (1.0 - skills.bonus("mitigation")) * (0.5 if fortify_timer > 0 else 1.0) * (0.25 if escape_timer > 0 else 1.0)
	health = maxf(0.0, health - amount)
	hurt_timer = 0.25
	if health == 0:
		blocking = false
		attack_phase = 0
		direction = Vector2.ZERO
		wants_block = false
		cast_id = ""
		sprinting = false
		collision_layer = 0
		collision_mask = 0

func update_hands(delta: float) -> void:
	if not sword or not shield:
		return
	sword.rotation.x = lerpf(sword.rotation.x, -0.95 if attack_phase == 2 else (0.65 if attack_phase == 1 else 0.0), minf(1.0, delta * 14.0))
	shield.position.y = lerpf(shield.position.y, -0.12 if blocking else -0.38, minf(1.0, delta * 14.0))
	var weapon = Catalog.get_item(inventory.weapon)
	sword.scale.y = weapon.reach / 2.4
	sword.material_override.albedo_color = weapon.tint
	shield.material_override.albedo_color = Catalog.get_item(inventory.shield).tint
	sword.visible = health > 0
	shield.visible = health > 0

func use_item(index: int) -> bool:
	if health <= 0 or attack_phase != 0 or cast_id != "" or index < 0 or index >= inventory.items.size():
		return false
	var item = Catalog.get_item(inventory.items[index])
	if item.kind == "consumable":
		if health >= max_health():
			return false
		health = minf(max_health(), health + item.heal)
		inventory.remove(index)
		return true
	if inventory.equip(index):
		empowered = ""
		return true
	return false

func max_health() -> float:
	return Combat.MAX_HEALTH + skills.bonus("hp")

func gain_xp(amount: int) -> void:
	skills.gain(amount)

func attack_cost() -> float:
	return Catalog.get_item(inventory.weapon).stamina_cost * (1.0 - skills.bonus("cost", skills.weapon_domain(inventory.weapon)))

func attack_speed_factor() -> float:
	return 1.0 - skills.bonus("speed", skills.weapon_domain(inventory.weapon))

func attack_damage() -> float:
	var multiplier := 1.0
	if empowered == "flurry":
		multiplier = 1.6
	elif empowered == "riposte":
		multiplier = 2.0
	elif empowered == "rage":
		multiplier = 1.8
	return Catalog.get_item(inventory.weapon).damage * (1.0 + skills.bonus("weapon", skills.weapon_domain(inventory.weapon)) + skills.bonus("damage")) * multiplier

func attack_reach() -> float:
	return Catalog.get_item(inventory.weapon).reach + skills.bonus("reach", skills.weapon_domain(inventory.weapon)) + (2.0 if empowered == "lunge" else 0.0)

func block_cost() -> float:
	return Combat.BLOCK_COST * (1.0 - skills.bonus("block"))

func activate(slot: int) -> bool:
	if health <= 0 or attack_phase != 0 or cast_id != "" or slot < 0 or slot >= Skills.SLOT_COUNT:
		return false
	var id: String = skills.slots[slot]
	if id == "" or not skills.learned.has(id) or skills.cooldowns.get(id, 0.0) > 0:
		return false
	var node := Skills.Talents.find(id)
	if node[1] in [1, 2, 3] and node[1] != skills.weapon_domain(inventory.weapon):
		return false
	if not Spells.get_spell(id).is_empty():
		return start_spell(id)
	var cooldown := 8.0
	match id:
		"wind":
			if stamina >= Combat.MAX_STAMINA:
				return false
			stamina = minf(Combat.MAX_STAMINA, stamina + 35)
			cooldown = 15.0
		"fortify":
			fortify_timer = 4.0
			cooldown = 18.0
		"dash":
			dash_timer = 1.0
		"escape":
			escape_timer = 2.0
			cooldown = 15.0
		"flurry", "rage", "lunge", "riposte", "cleave", "impale", "bash":
			if id == "riposte" and last_block <= 0:
				return false
			if empowered != "":
				return false
			empowered = id
			empower_timer = 5.0
			if id in ["rage", "impale", "bash"]:
				cooldown = 12.0
			elif id in ["riposte", "cleave"]:
				cooldown = 10.0
		_: return false
	skills.cooldowns[id] = cooldown
	return true

func buy_talent(id: String) -> bool:
	var old := max_health()
	if not skills.buy(id):
		return false
	health = minf(max_health(), health + max_health() - old)
	return true

func refund_talents(domain: int) -> bool:
	if not skills.refund(domain):
		return false
	health = minf(health, max_health())
	empowered = ""
	fortify_timer = 0.0
	dash_timer = 0.0
	escape_timer = 0.0
	return true

func update_sprint(delta: float) -> void:
	if not wants_sprint:
		sprint_exhausted = false
	sprinting = wants_sprint and not sprint_exhausted and direction.length_squared() > 0.01 and health > 0 and attack_phase == 0 and cast_id == "" and not wants_block and not blocking and stamina > 0
	if sprinting:
		stamina = maxf(0.0, stamina - 22.0 * delta * (1.0 - skills.bonus("sprint_cost")))
		if stamina <= 0:
			sprint_exhausted = true

func start_spell(id: String) -> bool:
	var stats := Spells.get_spell(id)
	if stats.is_empty() or not skills.learned.has(id) or cast_id != "" or attack_phase != 0 or health <= 0 or blocking or wants_block or skills.cooldowns.get(id, 0.0) > 0:
		return false
	var cost: float = float(stats[1]) * (1.0 - skills.bonus("mana_cost", stats[0]))
	if mana < cost:
		return false
	mana -= cost
	cast_id = id
	cast_timer = 0.4
	sprinting = false
	combat_timer = 5.0
	skills.cooldowns[id] = stats[5]
	return true

func advance_cast(delta: float) -> String:
	if cast_id == "" or health <= 0:
		return ""
	cast_timer -= delta
	if cast_timer > 0:
		return ""
	var id := cast_id
	cast_id = ""
	return id
