extends Node3D

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
	speed = lerpf(speed, minf(7.0, distance / maxf(delta, 0.001)) if distance < 2.0 else 0.0, minf(1.0, delta * 10.0))
	clock += delta * (3.0 + speed * 2.2)
	var bob := sin(clock) * minf(1.0, speed / 4.5) * 0.028 * motion
	var potions: int = actor.inventory.count("potion") + actor.inventory.belt
	if last_hp >= 0.0 and actor.health > last_hp and potions < last_potions:
		drink_time = 0.85
	last_hp = actor.health
	last_potions = potions
	drink_time = maxf(0.0, drink_time - delta)
	var weight := minf(1.0, delta * 15.0)
	var casting: bool = actor.cast_id != ""
	if (last_phase == 1 and actor.attack_phase == 2) or (last_cast != "" and not casting):
		release_time = 0.18
	last_phase = actor.attack_phase
	last_cast = actor.cast_id
	release_time = maxf(0.0, release_time - delta)
	cast_charge = move_toward(cast_charge, 1.0 if casting else 0.0, delta * 4.0)
	if casting:
		var stats := Spells.get_spell(actor.cast_id)
		if not stats.is_empty():
			cast_color = stats[6]
	spell_material.albedo_color = cast_color
	spell_material.emission = cast_color
	var target := Vector3(0.36 + bob, -0.33 + absf(bob), -0.75)
	var rot := Vector3(0.10, -0.15, -0.14)
	if actor.attack_phase == 1:
		target += Vector3(0.15, 0.12, 0.05)
		rot = Vector3(0.75, -0.5, -0.35)
	elif actor.attack_phase == 2:
		target += Vector3(-0.24, 0.08, -0.17)
		rot = Vector3(-0.8, 0.55, 0.70)
	if actor.attack_phase != 0:
		var item_id: String = key[0]
		var windup: bool = actor.attack_phase == 1
		if Catalog.get_item(item_id).projectile_speed > 0:
			target = Vector3(0.23, -0.19, -0.70 if windup else -0.86)
			rot = Vector3(-0.12, -0.25, -0.08)
		elif "spear" in item_id or "dagger" in item_id:
			target = Vector3(0.32, -0.25, -0.55 if windup else -1.03)
			rot = Vector3(0.1, -0.12, -0.18)
		elif "axe" in item_id:
			target.y += 0.18 if windup else -0.08
			rot.x = 1.15 if windup else -1.25
	if casting:
		target = Vector3(0.22, -0.16, -0.72)
		rot.x = -0.4
	target.z += release_time * 0.45
	rot.x += release_time * 1.3
	right.position = right.position.lerp(target, weight)
	right.rotation = right.rotation.lerp(rot, weight)
	var left_target := Vector3(-0.40 - bob, -0.38 + absf(bob), -0.76)
	if casting:
		left_target = Vector3(-0.22, -0.14, -0.66)
	elif Catalog.get_item(key[0]).projectile_speed > 0 and actor.attack_phase == 1:
		left_target = Vector3(-0.12, -0.19, -0.48)
	if actor.blocking:
		left_target = Vector3(-0.19, -0.09, -0.64)
	if drink_time > 0.0:
		left_target = Vector3(-0.15, 0.02, -0.47)
	left.position = left.position.lerp(left_target, weight)
	left.rotation.x = lerpf(left.rotation.x, -0.35 if actor.blocking else (0.9 if drink_time > 0.0 else 0.0), weight)
	drink.visible = drink_time > 0.0
	if shield:
		shield.visible = not drink.visible
	spell.visible = casting or (release_time > 0.0 and cast_charge > 0.0)
	spell.scale = Vector3.ONE * maxf(0.05, cast_charge * (0.9 + sin(clock * 8.0) * 0.1))
	spell.rotation.y += delta * 3.0
	visible = actor.health > 0.0
