extends Node3D

const Motion = preload("res://game/visuals/motion_curves.gd")
const Spells = preload("res://game/combat/spells.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Assets = preload("res://game/visuals/asset_registry.gd")
const Loot = preload("res://game/items/loot_models.gd")
var right: Node3D
var left: Node3D
var weapon: Node3D
var shield: Node3D
var drink: Node3D
var spell: Node3D
var key: Array = []
var last_hp := -1.0
var last_potions := -1
var drink_time := 0.0
var clock := 0.0
var speed := 0.0
var previous := Vector3.ZERO
var sampled := false
var last_phase := 0
var last_cast := ""
var release_time := 0.0
var cast_charge := 0.0
var cast_color := Color.WHITE
var spell_material: StandardMaterial3D
var equip_time := 0.0
var previous_aim := Vector2.ZERO
var sway := Vector2.ZERO
var last_drawing := false
var breath_clock := 0.0
var previous_velocity := Vector3.ZERO
var inertia := Vector3.ZERO
var aim_blend := 0.0
var cast_pose := 0.0
var cast_release := 0.0

func _ready() -> void:
	right = Node3D.new()
	left = Node3D.new()
	add_child(right)
	add_child(left)
	for hand in [right, left]:
		Loot.box(hand, Vector3(0, -0.11, 0.18), Vector3(0.14, 0.14, 0.36), Loot.LEATHER, Vector3(-0.12, 0, 0))
		Loot.gem(hand, Vector3.ZERO, 0.095, Color("#b98e69"))
	drink = Loot.build("potion", left)
	drink.position = Vector3(0, 0.09, -0.03)
	drink.hide()
	spell = Node3D.new()
	add_child(spell)
	Loot.gem(spell, Vector3.ZERO, 0.13, Color("#c3a1e8"))
	spell_material = StandardMaterial3D.new()
	spell_material.emission_enabled = true
	var orb := spell.get_child(0) as MeshInstance3D
	if orb:
		orb.material_override = spell_material
	spell.position = Vector3(0, -0.15, -0.76)
	spell.hide()

func animate(actor, delta: float, motion: float) -> void:
	var next: Array = [actor.inventory.weapon, actor.inventory.shield]
	if next != key:
		equip_time = 0.35
		key = next
		weapon = Assets.replace_held(weapon, key[0], right)
		shield = Assets.replace_held(shield, key[1], left, true)
		if weapon:
			weapon.scale = Vector3.ONE * 0.85
		if shield:
			shield.scale = Vector3.ONE * 0.9
	var at: Vector3 = actor.global_position
	var distance := Vector2(at.x - previous.x, at.z - previous.z).length() if sampled and absf(at.y - previous.y) < 5.0 else 0.0
	previous = at
	sampled = true
	speed = lerpf(speed, minf(7.0, distance / maxf(delta, 0.001)) if distance < 2.0 else 0.0, Motion.blend(delta, 10.0))
	clock += delta * speed * 2.6
	breath_clock += delta * 1.8
	var bob := sin(clock) * minf(1.0, speed / 4.5) * 0.028 * motion
	var breath := sin(breath_clock) * 0.008 * motion
	var potions: int = actor.inventory.count("potion") + actor.inventory.belt
	if last_hp >= 0.0 and actor.health > last_hp and potions < last_potions:
		drink_time = 0.85
	last_hp = actor.health
	last_potions = potions
	drink_time = maxf(0.0, drink_time - delta)
	var weight := Motion.blend(delta, 22.0)
	var casting: bool = actor.cast_id != ""
	var aim := Vector2(actor.camera.global_rotation.y, actor.camera.rotation.x) if actor.camera else Vector2(actor.heading, actor.look_pitch)
	var aim_change := Vector2(wrapf(aim.x - previous_aim.x, -PI, PI), aim.y - previous_aim.y)
	previous_aim = aim
	sway = sway.lerp((aim_change / maxf(delta, 0.001) * -0.012).limit_length(0.12), Motion.blend(delta, 14.0))
	aim_blend = lerpf(aim_blend, 1.0 if actor.aiming else 0.0, Motion.blend(delta, 12.0))
	var local_velocity: Vector3 = actor.global_basis.inverse() * actor.velocity
	inertia = inertia.lerp(((previous_velocity - local_velocity) * 0.012).limit_length(0.06), Motion.blend(delta, 8.0))
	previous_velocity = local_velocity
	equip_time = maxf(0.0, equip_time - delta)
	if last_drawing and not actor.bow_drawing and actor.attack_phase != 0:
		release_time = 0.18
	last_drawing = actor.bow_drawing
	if last_cast != "" and not casting:
		cast_release = 0.24
	if (last_phase == 1 and actor.attack_phase == 2) or (last_cast != "" and not casting):
		release_time = 0.18
	last_phase = actor.attack_phase
	last_cast = actor.cast_id
	release_time = maxf(0.0, release_time - delta)
	cast_release = maxf(0.0, cast_release - delta)
	cast_pose = lerpf(cast_pose, 1.0 if casting else 0.0, Motion.blend(delta, 12.0))
	cast_charge = move_toward(cast_charge, 1.0 if casting else 0.0, delta * 4.0)
	if casting:
		var stats := Spells.get_spell(actor.cast_id)
		if not stats.is_empty():
			cast_color = stats[6]
	spell_material.albedo_color = cast_color
	spell_material.emission = cast_color
	var target := Vector3(0.36 + bob, -0.33 + absf(bob) + breath, -0.75)
	var rot := Vector3(0.10, -0.15, -0.14)
	var item = Catalog.get_item(key[0])
	var poses := Motion.swing(key[0])
	var offset: Vector3 = Vector3.ZERO
	var rotation_offset: Vector3 = Vector3.ZERO
	if actor.attack_phase == 1:
		var p := Motion.smooth(Motion.progress(actor.attack_timer, item.windup * actor.attack_speed_factor()))
		offset = Vector3.ZERO.lerp(poses[0], p)
		rotation_offset = Vector3.ZERO.lerp(poses[1], p)
	elif actor.attack_phase == 2:
		var p := Motion.progress(actor.attack_timer, item.recovery * actor.attack_speed_factor())
		var windup: Vector3 = poses[0]
		var windup_rot: Vector3 = poses[1]
		offset = windup.lerp(poses[2], Motion.strike(p)).lerp(Vector3.ZERO, Motion.settle(p))
		rotation_offset = windup_rot.lerp(poses[3], Motion.strike(p)).lerp(Vector3.ZERO, Motion.settle(p))
	target += offset
	rot += rotation_offset
	if cast_pose > 0.01:
		var spell_target := Vector3(0.22, -0.16, -0.72)
		if actor.cast_id == "fireball":
			spell_target += Vector3(0.12, 0.15, 0.10)
		elif actor.cast_id in ["spark", "thunder"]:
			spell_target.z -= 0.15
		elif actor.cast_id in ["stonebolt", "boulder"]:
			spell_target.y -= 0.10
		target = target.lerp(spell_target, cast_pose)
		rot = rot.lerp(Vector3(-0.4, -0.15, -0.25), cast_pose)
	target.z -= sin(cast_release / 0.24 * PI) * 0.17
	if actor.bow_drawing:
		target = Vector3(0.18, -0.18, -0.78)
		rot = Vector3(-0.08, -0.2, -0.08)
	target.x *= lerpf(1.0, 0.5, aim_blend)
	target.y += 0.08 * aim_blend
	var draw_weight := 1.4 if "axe" in str(key[0]) else (0.8 if "dagger" in str(key[0]) else 1.0)
	target.y -= Motion.smooth(equip_time / 0.35) * 0.35 * draw_weight
	rot.x += equip_time * 1.5 * draw_weight
	target += (Vector3(sway.x, sway.y, 0.0) + inertia) * motion * (1.0 - aim_blend * 0.6)
	target.z += release_time * 0.45
	rot.x += release_time * 1.3
	right.position = right.position.lerp(target, weight)
	right.rotation = right.rotation.lerp(rot, weight)
	var left_target := Vector3(-0.40 - bob, -0.38 + absf(bob) + breath, -0.76)
	if actor.bow_drawing:
		left_target = Vector3(-0.12, -0.18, lerpf(-0.72, -0.30, Motion.smooth(actor.bow_charge)))
	elif casting:
		left_target = Vector3(-0.22, -0.14, -0.66)
	elif Catalog.get_item(key[0]).projectile_speed > 0 and actor.attack_phase == 1:
		left_target = Vector3(-0.12, -0.19, -0.48)
	if actor.blocking:
		left_target = Vector3(-0.19, -0.09, -0.64)
	if drink_time > 0.0:
		var lift := sin(PI * (1.0 - drink_time / 0.85))
		left_target = left_target.lerp(Vector3(-0.15, 0.02, -0.47), lift)
	left_target += Vector3(sway.x, sway.y, 0.0) * motion * 0.65
	left.position = left.position.lerp(left_target, weight)
	left.rotation.x = lerpf(left.rotation.x, -0.35 if actor.blocking else (0.9 if drink_time > 0.0 else 0.0), weight)
	drink.visible = drink_time > 0.0
	if shield:
		shield.visible = not drink.visible and not casting and not actor.bow_drawing
	spell.visible = casting or (release_time > 0.0 and cast_charge > 0.0)
	spell.scale = Vector3.ONE * maxf(0.05, cast_charge * (0.9 + sin(clock * 8.0) * 0.1))
	spell.rotation.y += delta * 3.0
	visible = actor.health > 0.0
