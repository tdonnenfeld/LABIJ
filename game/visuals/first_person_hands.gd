extends Node3D

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
	var target := Vector3(0.36 + bob, -0.33 + absf(bob), -0.75)
	var rot := Vector3(0.10, -0.15, -0.14)
	if actor.attack_phase == 1:
		target += Vector3(0.15, 0.12, 0.05)
		rot = Vector3(0.75, -0.5, -0.35)
	elif actor.attack_phase == 2:
		target += Vector3(-0.24, 0.08, -0.17)
		rot = Vector3(-0.8, 0.55, 0.70)
	if casting:
		target = Vector3(0.22, -0.16, -0.72)
		rot.x = -0.4
	right.position = right.position.lerp(target, weight)
	right.rotation = right.rotation.lerp(rot, weight)
	var left_target := Vector3(-0.40 - bob, -0.38 + absf(bob), -0.76)
	if actor.blocking:
		left_target = Vector3(-0.19, -0.09, -0.64)
	if drink_time > 0.0:
		left_target = Vector3(-0.15, 0.02, -0.47)
	left.position = left.position.lerp(left_target, weight)
	left.rotation.x = lerpf(left.rotation.x, -0.35 if actor.blocking else (0.9 if drink_time > 0.0 else 0.0), weight)
	drink.visible = drink_time > 0.0
	if shield:
		shield.visible = not drink.visible
	spell.visible = casting
	spell.scale = Vector3.ONE * (0.85 + sin(clock * 3.0) * 0.18)
	visible = actor.health > 0.0
