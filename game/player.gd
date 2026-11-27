extends CharacterBody3D

const Combat = preload("res://game/combat.gd")
const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
var inventory := Inventory.new()
const Skills = preload("res://game/progression/skills.gd")
const Profiles = preload("res://game/progression/profiles.gd")
var species_id := 0
var background_id := 0
var profile_locked := false
const Spells = preload("res://game/combat/spells.gd")
var mana := 100.0
var lantern_lit := true
var wants_sprint := false
var wants_quiet := false
var quiet_walking := false
var noise_level := 0.0
var noise_peak := 0.0
var noise_hold := 0.0
var step_distance := 0.0
var sprinting := false
var sprint_exhausted := false
var cast_id := ""
var cast_timer := 0.0
var spell_voice := 0
var announce_spell := false
var skills := Skills.new()
var combat_timer := 0.0
var fortify_timer := 0.0
var dash_timer := 0.0
var escape_timer := 0.0
var last_block := 0.0
var block_age := 1.0
var empowered := ""
var empower_timer := 0.0

signal damage_event(amount: float, blocked: bool, parried: bool, source_name: String)
signal xp_event(amount: int)
var display_name := "Player"
var health := Combat.MAX_HEALTH
var stamina := Combat.MAX_STAMINA
var blocking := false
var wants_block := false
var attack_phase := 0
var attack_timer := 0.0
var hurt_timer := 0.0
var last_damage_source := Vector3.INF
var swing_hit := false
const ActorRig = preload("res://game/visuals/actor_rig.gd")
const Hands = preload("res://game/visuals/first_person_hands.gd")
var character_rig: Node3D
var hands: Node3D
var floor_id := 0
var direction := Vector2.ZERO
var heading := 0.0
var look_pitch := 0.0
var selected_spell := ""
var aiming := false
var bow_charge := 0.0
var bow_drawing := false
var shot_power := 1.0
var trigger_held := false
var beam_active := false
var camera: Camera3D

func setup(local: bool, visual: bool = true) -> void:
	spell_voice = randi_range(0, 7)
	collision_layer = 2
	collision_mask = 7
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collision.shape = capsule
	add_child(collision)
	if not visual:
		return
	if not local:
		character_rig = ActorRig.new()
		add_child(character_rig)
		character_rig.setup("adventurer", 1.7)
	if local:
		camera = Camera3D.new()
		camera.position.y = 0.55
		camera.current = true
		add_child(camera)
		var light := OmniLight3D.new()
		light.name = "Lantern"
		light.omni_range = 11
		light.omni_attenuation = 1.4
		light.light_color = Color("#f0d5aa")
		light.light_energy = 2.5 if "--debug-geometry" in OS.get_cmdline_user_args() else 1.5
		camera.add_child(light)
		hands = Hands.new()
		camera.add_child(hands)

func simulate(delta: float) -> void:
	if health <= 0.0:
		sprinting = false
		velocity = Vector3.ZERO
		return
	rotation.y = heading
	quiet_walking = wants_quiet and not wants_sprint and not bow_drawing and dash_timer <= 0 and attack_phase == 0 and cast_id == ""
	update_sprint(delta)
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(cos(heading), 0, -sin(heading))
	var weapon = Catalog.get_item(inventory.weapon)
	var attack_move := 3.4 if weapon.projectile_speed <= 0 else 2.5
	var move_speed := 2.5 if blocking or aiming else (attack_move if attack_phase == 1 else (3.8 if attack_phase == 2 else 4.5))
	var motion := (right * direction.x + forward * direction.y) * move_speed * (1.0 + skills.bonus("move")) * float(Profiles.SPECIES[species_id][3]) * (2.0 if dash_timer > 0 else (1.55 if sprinting else (0.45 * (1.0 + skills.bonus("quiet_speed")) if quiet_walking else 1.0)))
	var planar := Vector2(velocity.x, velocity.z)
	var desired := Vector2(motion.x, motion.z)
	var acceleration := 36.0 if desired.length_squared() > 0.001 else 48.0
	if direction.length_squared() <= 0.001 and planar.length() < 0.08:
		planar = Vector2.ZERO
	else:
		planar = planar.move_toward(desired, acceleration * delta)
	velocity.x = planar.x
	velocity.z = planar.y
	velocity.y = maxf(velocity.y - 18.0 * delta, -20.0)
	move_and_slide()

func ranged_mode() -> bool:
	return not selected_spell.is_empty() or Catalog.get_item(inventory.weapon).projectile_speed > 0

func select_spell(slot: int) -> bool:
	if slot == -1:
		selected_spell = ""
		return true
	if slot < 0 or slot >= Skills.SLOT_COUNT:
		return false
	var id: String = skills.slots[slot]
	if Spells.get_spell(id).is_empty() or not skills.learned.has(id):
		return false
	selected_spell = id
	return true

func set_trigger(held: bool, cancel: bool = false) -> void:
	if held == trigger_held and not cancel:
		return
	trigger_held = held
	if cancel:
		if beam_active:
			cast_id = ""
			beam_active = false
		bow_drawing = false
		bow_charge = 0.0
		return
	if not held:
		if beam_active:
			cast_id = ""
			beam_active = false
		if bow_drawing:
			bow_drawing = false
			if begin_attack():
				shot_power = clampf(bow_charge, 0.25, 1.0)
				attack_timer = 0.01
			bow_charge = 0.0
		return
	if not selected_spell.is_empty():
		if skills.slots.has(selected_spell) and start_spell(selected_spell):
			beam_active = selected_spell == "spark"
	elif Catalog.get_item(inventory.weapon).projectile_speed > 0:
		if health > 0 and attack_phase == 0 and cast_id == "" and not blocking and stamina >= attack_cost() and inventory.count("arrows") > 0:
			bow_drawing = true
			bow_charge = 0.0
	else:
		begin_attack()

func begin_attack() -> bool:
	var weapon = Catalog.get_item(inventory.weapon)
	if health <= 0 or bow_drawing or attack_phase != 0 or cast_id != "" or blocking or (wants_block and inventory.shield_index >= 0) or stamina < attack_cost():
		return false
	if weapon.projectile_speed > 0 and inventory.count("arrows") == 0:
		return false
	sprinting = false
	shot_power = 1.0
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
	if bow_drawing:
		bow_charge = minf(1.0, bow_charge + delta / 0.9)
		if not trigger_held or Catalog.get_item(inventory.weapon).projectile_speed <= 0:
			bow_drawing = false
			bow_charge = 0.0
	var was_blocking := blocking
	blocking = inventory.shield_index >= 0 and not ranged_mode() and wants_block and attack_phase == 0 and cast_id == "" and stamina > 0
	if blocking:
		block_age = block_age + delta if was_blocking else 0.0
	mana = minf(100.0, mana + delta * 5.0 * float(Profiles.SPECIES[species_id][4]) * (1.0 + Catalog.get_item(inventory.weapon).mana_bonus + oracle_bonus()))
	if not blocking and not sprinting and not bow_drawing and attack_phase == 0 and cast_id == "":
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

func take_damage(amount: float, source: Vector3, magical: bool = false, source_name: String = "Enemy") -> void:
	if health <= 0:
		return
	last_damage_source = source
	var before := health
	var blocked := false
	var parried := false
	if inventory.shield_index >= 0 and blocking and stamina >= block_cost() and Combat.facing(heading, source - position):
		blocked = true
		stamina -= block_cost()
		amount *= 1.0 - minf(0.95, Catalog.get_item(inventory.shield).reduction + skills.bonus("reduction"))
		skills.credit(4, 5)
		last_block = 3.0
		stamina = minf(Combat.MAX_STAMINA, stamina + skills.bonus("block_restore"))
		if skills.bonus("parry") > 0 and block_age <= 0.25:
			amount = 0.0
			parried = true
	combat_timer = 5.0
	for index in [inventory.armor_index] + inventory.accessories:
		if index >= 0:
			var armor = Catalog.get_item(inventory.items[index])
			amount *= 1.0 - armor.armor
			if magical:
				amount *= 1.0 - armor.magic_resistance
	amount *= (1.0 - skills.bonus("mitigation")) * (0.5 if fortify_timer > 0 else 1.0) * (0.25 if escape_timer > 0 else 1.0)
	amount *= 1.0 - warden_bonus()
	health = maxf(0.0, health - amount)
	damage_event.emit(before - health, blocked, parried, source_name)
	hurt_timer = 0.25
	if health == 0:
		set_trigger(false, true)
		blocking = false
		attack_phase = 0
		direction = Vector2.ZERO
		wants_block = false
		cast_id = ""
		sprinting = false
		collision_layer = 0
		collision_mask = 0

func update_hands(delta: float, motion: float = 1.0, remote: bool = false) -> void:
	if camera:
		var lantern := camera.get_node_or_null("Lantern") as OmniLight3D
		if lantern:
			lantern.light_energy = lerpf(lantern.light_energy, 1.5 if lantern_lit else 0.12, minf(1.0, delta * 8.0))
	if remote:
		attack_timer = maxf(0.0, attack_timer - delta)
		cast_timer = maxf(0.0, cast_timer - delta)
	var weapon = Catalog.get_item(inventory.weapon)
	var duration: float = (weapon.windup if attack_phase == 1 else weapon.recovery) * attack_speed_factor()
	var progress := clampf(1.0 - attack_timer / maxf(duration, 0.001), 0.0, 1.0)
	if hands:
		hands.animate(self, delta, motion)
	if character_rig:
		character_rig.equip_inventory(inventory)
		character_rig.animate(delta, health > 0.0, 1 if bow_drawing else attack_phase, false, hurt_timer > 0, blocking, cast_id != "", 0.0, bow_charge if bow_drawing else progress)

func use_item(index: int) -> bool:
	if health <= 0 or attack_phase != 0 or cast_id != "" or index < 0 or index >= inventory.items.size():
		return false
	var item = Catalog.get_item(inventory.items[index])
	if item.kind == "scroll":
		if not skills.read_scroll(item.spell_id):
			return false
		inventory.remove(index)
		return true
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
	return Combat.MAX_HEALTH + float(Profiles.SPECIES[species_id][2]) + skills.bonus("hp")

func gain_xp(amount: int) -> void:
	skills.gain(amount)
	if amount > 0:
		xp_event.emit(amount)

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

func update_sprint(delta: float) -> void:
	if not wants_sprint:
		sprint_exhausted = false
	sprinting = wants_sprint and not sprint_exhausted and direction.length_squared() > 0.01 and health > 0 and attack_phase == 0 and cast_id == "" and not wants_block and not blocking and not aiming and not bow_drawing and stamina > 0
	if sprinting:
		stamina = maxf(0.0, stamina - 22.0 * delta * (1.0 - skills.bonus("sprint_cost")))
		if stamina <= 0:
			sprint_exhausted = true

func start_spell(id: String) -> bool:
	var stats := Spells.get_spell(id)
	if bow_drawing or stats.is_empty() or not skills.learned.has(id) or cast_id != "" or attack_phase != 0 or health <= 0 or blocking or wants_block or skills.cooldowns.get(id, 0.0) > 0:
		return false
	var cost: float = float(stats[1]) * (1.0 - skills.bonus("mana_cost", stats[0]))
	if mana < cost:
		return false
	mana -= cost
	cast_id = id
	announce_spell = true
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
	if beam_active and id == "spark" and trigger_held and selected_spell == id and mana >= 3.0:
		mana -= 3.0
		cast_timer = 0.15
		return id
	cast_id = ""
	beam_active = false
	return id

func configure_profile(chosen_name: String, species: int, background: int) -> bool:
	if profile_locked or not Profiles.valid(species, background):
		return false
	display_name = Profiles.clean_name(chosen_name)
	if display_name.is_empty():
		display_name = "Player"
	species_id = species
	background_id = background
	profile_locked = true
	var start: Array = Profiles.BACKGROUNDS[background]
	inventory.reset_items(start[2])
	if Catalog.get_item(inventory.weapon).projectile_speed > 0:
		inventory.add("arrows", 24)
	skills.priorities.assign(start[3])
	skills.aptitudes = Profiles.SPECIES[species][6].duplicate()
	if start[4] >= 0:
		skills.credit(start[4], 25.0)
	health = max_health()
	return true

func register_noise(radius: float) -> void:
	noise_level = maxf(noise_level, radius)
	if radius >= noise_peak:
		noise_peak = radius
		noise_hold = 0.65

func decay_noise(delta: float) -> void:
	noise_level = maxf(0.0, noise_level - delta * 8.0)
	var falling_time := maxf(0.0, delta - noise_hold)
	noise_hold = maxf(0.0, noise_hold - delta)
	noise_peak = maxf(noise_level, noise_peak - falling_time * 2.0)

func drink_belt(slot: int) -> bool:
	if health <= 0 or health >= max_health() or attack_phase != 0 or cast_id != "":
		return false
	if not inventory.consume_belt(slot):
		return false
	health = minf(max_health(), health + Catalog.get_item("potion").heal)
	return true

func warden_bonus() -> float:
	var pieces := inventory.set_pieces("Warden")
	return 0.15 if pieces >= 3 else (0.08 if pieces >= 2 else 0.0)

func oracle_bonus() -> float:
	var pieces := inventory.set_pieces("Oracle")
	return 0.35 if pieces >= 3 else (0.20 if pieces >= 2 else 0.0)
