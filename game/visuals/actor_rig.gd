extends Node3D

const Assets = preload("res://game/visuals/asset_registry.gd")
const Loot = preload("res://game/items/loot_models.gd")
var model: Node3D
var body: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_r: Node3D
var leg_l: Node3D
var tail: Node3D
var head: Node3D
var grip_r: Node3D
var grip_l: Node3D
var right_item: Node3D
var left_item: Node3D
var worn: Array[Node3D] = []
var gear_key: Array = []
var previous := Vector3.ZERO
var sampled := false
var speed := 0.0
var clock := 0.0
var pose := 0.0
var ever_alive := false
var kind := ""
var height := 1.7
var is_rat := false

func setup(id: String, h: float) -> void:
	kind = id
	height = h
	is_rat = id == "rat"
	position.y = -height * 0.5
	model = Assets.character(id, self)
	model.scale = Vector3.ONE * height / (0.58 if is_rat else (1.23 if id in ["crypt_warden", "jewel_sentinel"] else 1.08))
	body = model.find_child("Body", true, false) as Node3D
	arm_r = model.find_child("ArmL", true, false) as Node3D
	arm_l = model.find_child("ArmR", true, false) as Node3D
	leg_r = model.find_child("LegL", true, false) as Node3D
	leg_l = model.find_child("LegR", true, false) as Node3D
	tail = model.find_child("Tail", true, false) as Node3D
	head = model.find_child("Head", true, false) as Node3D
	grip_r = model.find_child("GripL", true, false) as Node3D
	grip_l = model.find_child("GripR", true, false) as Node3D
	if grip_r and grip_l:
		var weapon: String = {"goblin": "venom_dagger", "brute": "axe", "archer": "bow", "guardian": "sword", "mage": "staff", "crypt_warden": "axe", "ember_oracle": "ember_staff", "jewel_sentinel": "spear", "jewel_hunter": "venom_dagger"}.get(id, "unarmed")
		right_item = Assets.held(weapon, grip_r)
		if id in ["guardian", "crypt_warden", "jewel_sentinel"]:
			left_item = Assets.held("iron_shield", grip_l, true)
		for item in [right_item, left_item]:
			if is_instance_valid(item):
				item.scale = Vector3.ONE * 0.7

func equip_inventory(bag) -> void:
	var key: Array = [bag.weapon, bag.shield]
	for slot in range(2, bag.SLOT_KINDS.size()):
		var index: int = bag.slot_index(slot)
		key.append(bag.items[index] if index >= 0 else "")
	if key == gear_key:
		return
	gear_key = key
	if grip_r and grip_l:
		right_item = Assets.replace_held(right_item, key[0], grip_r)
		left_item = Assets.replace_held(left_item, key[1], grip_l, true)
		for item in [right_item, left_item]:
			if is_instance_valid(item):
				item.scale = Vector3.ONE * 0.72
	for piece in worn:
		piece.hide()
		piece.queue_free()
	worn.clear()
	if body and key[2] != "":
		var chest := Loot.part(body, BoxMesh.new(), Vector3(0, 0.70, -0.13), Loot.LEATHER if key[2] == "leather" else Loot.STEEL)
		chest.scale = Vector3(0.42, 0.30, 0.13)
		worn.append(chest)
	if head and key[3] != "":
		var helm := Loot.build(key[3], head)
		helm.position = Vector3(0, 0.04, 0)
		helm.scale = Vector3.ONE * 0.9
		worn.append(helm)
	for pair in [[arm_r, 4, -0.33], [arm_l, 4, -0.33], [leg_r, 5, -0.40], [leg_l, 5, -0.40]]:
		if pair[0] and key[pair[1]] != "":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.17, 0.13, 0.18)
			worn.append(Loot.part(pair[0], mesh, Vector3(0, pair[2], 0), Loot.LEATHER if pair[1] == 4 else Loot.STEEL))
	if body and key[6] != "":
		var amulet := Loot.build(key[6], body)
		amulet.position = Vector3(0, 0.78, -0.19)
		amulet.scale = Vector3.ONE * 0.35
		worn.append(amulet)
	for pair in [[grip_r, 7], [grip_l, 8]]:
		if pair[0] and key[pair[1]] != "":
			var ring := Loot.build(key[pair[1]], pair[0])
			ring.position = Vector3.ZERO
			ring.scale = Vector3.ONE * 0.24
			worn.append(ring)

func angle(part: Node3D, target: float, weight: float) -> void:
	if part:
		part.rotation.x = lerpf(part.rotation.x, target, weight)

func animate(delta: float, alive: bool, phase: int, asleep: bool, hurt: bool, blocking: bool = false, casting: bool = false, hit_direction: float = 0.0) -> void:
	var at := get_parent_node_3d().global_position
	var distance := Vector2(at.x - previous.x, at.z - previous.z).length() if sampled and absf(at.y - previous.y) < 5.0 else 0.0
	previous = at
	sampled = true
	if distance > 3.0:
		distance = 0.0
	speed = lerpf(speed, minf(8.0, distance / maxf(delta, 0.001)), minf(1.0, delta * 12.0))
	ever_alive = ever_alive or alive
	var weight := minf(1.0, delta * 10.0)
	var prone := -PI * 0.5 if not alive else (-PI * 0.45 if asleep and not is_rat else 0.0)
	pose = lerpf(pose, prone, weight)
	model.rotation.x = pose
	if not alive or asleep:
		for part in [arm_r, arm_l, leg_r, leg_l]:
			angle(part, 0.0, weight)
		return
	clock += delta * (2.0 + speed * (4.0 if is_rat else 2.0))
	var gait := sin(clock) * clampf(speed / 2.3, 0.0, 1.0) * (0.52 if kind == "brute" else 0.76)
	angle(leg_r, gait, weight)
	angle(leg_l, -gait, weight)
	var windup := -1.45
	var release := 0.65
	match kind:
		"brute", "crypt_warden": 
			windup = -2.0
			release = 1.0
		"guardian", "jewel_sentinel":
			windup = -0.85
			release = -1.65
		"archer", "mage", "ember_oracle":
			windup = -1.15
			release = -0.7
		"goblin", "jewel_hunter":
			windup = -1.8
			release = 0.9
	var attack := windup if phase == 1 else (release if phase == 2 else -gait * 0.65)
	if is_rat:
		attack = -gait
		if phase == 1:
			attack = -0.65
		elif phase == 2:
			attack = 0.55
	angle(arm_r, -1.15 if casting else attack, weight)
	angle(arm_l, -1.4 if blocking or casting or (kind == "archer" and phase == 1) else gait * 0.65, weight)
	if body:
		body.position.y = lerpf(body.position.y, absf(gait) * 0.025 + sin(clock * 0.5) * 0.006, weight)
		body.rotation.z = lerpf(body.rotation.z, (-hit_direction * 0.28) if hurt else gait * 0.035, weight)
		body.rotation.x = lerpf(body.rotation.x, 0.18 if hurt else (-0.12 if phase == 1 else (0.12 if phase == 2 else 0.0)), weight)
	if head:
		head.rotation.x = lerpf(head.rotation.x, -0.12 if phase == 1 else (0.08 if hurt else sin(clock * 0.5) * 0.025), weight)
	if tail:
		tail.rotation.y = sin(clock) * 0.35
