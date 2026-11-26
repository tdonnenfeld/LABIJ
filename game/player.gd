extends CharacterBody3D

const Combat = preload("res://game/combat.gd")
const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
var inventory := Inventory.new()
const Skills = preload("res://game/progression/skills.gd")
var skills := Skills.new()

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
		velocity = Vector3.ZERO
		return
	rotation.y = heading
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(cos(heading), 0, -sin(heading))
	var motion := (right * direction.x + forward * direction.y) * (2.5 if blocking or attack_phase == 1 else 4.5)
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
	if health <= 0 or attack_phase != 0 or blocking or stamina < attack_cost():
		return false
	stamina -= attack_cost()
	attack_phase = 1
	attack_timer = weapon.windup * attack_speed_factor()
	swing_hit = false
	return true

func advance_combat(delta: float) -> bool:
	hurt_timer = maxf(0.0, hurt_timer - delta)
	if health <= 0:
		return false
	blocking = wants_block and attack_phase == 0 and stamina > 0
	if not blocking and attack_phase == 0:
		stamina = minf(Combat.MAX_STAMINA, stamina + delta * 18.0)
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
		amount *= 1.0 - Catalog.get_item(inventory.shield).reduction
	amount *= 1.0 - minf(0.25, skills.skill_level(5) * 0.01)
	health = maxf(0.0, health - amount)
	hurt_timer = 0.25
	if health == 0:
		blocking = false
		attack_phase = 0
		direction = Vector2.ZERO
		wants_block = false
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
	if health <= 0 or attack_phase != 0 or index < 0 or index >= inventory.items.size():
		return false
	var item = Catalog.get_item(inventory.items[index])
	if item.kind == "consumable":
		if health >= max_health():
			return false
		health = minf(max_health(), health + item.heal)
		inventory.remove(index)
		return true
	return inventory.equip(index)

func max_health() -> float:
	return Combat.MAX_HEALTH + skills.skill_level(0) * 4.0

func gain_xp(amount: int) -> void:
	var old_max := max_health()
	skills.gain(amount)
	health = minf(max_health(), health + max_health() - old_max)

func attack_cost() -> float:
	return Catalog.get_item(inventory.weapon).stamina_cost * maxf(0.65, 1.0 - skills.weapon_level(inventory.weapon) * 0.015)

func attack_speed_factor() -> float:
	return maxf(0.65, 1.0 - skills.weapon_level(inventory.weapon) * 0.015)

func attack_damage() -> float:
	return Catalog.get_item(inventory.weapon).damage * (1.0 + 0.035 * skills.weapon_level(inventory.weapon) + 0.02 * skills.skill_level(0))

func block_cost() -> float:
	return Combat.BLOCK_COST * maxf(0.5, 1.0 - skills.skill_level(4) * 0.02)
