extends Node3D

const ArticulatedSkeleton = preload("res://game/visuals/articulated_skeleton.gd")
const Motion = preload("res://game/visuals/motion_curves.gd")
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
var breath_clock := 0.0
var turn_lean := 0.0
var previous_yaw := 0.0
var phase_age := 0.0
var last_phase := 0
var flinch := 0.0
var was_hurt := false
var body_rest := Vector3.ZERO
var skeleton: ArticulatedSkeleton
var elbow_r: Node3D
var elbow_l: Node3D
var knee_r: Node3D
var knee_l: Node3D
var strafe := 0.0
var stride_direction := 1.0

func setup(id: String, h: float) -> void:
	kind = id
	height = h
	is_rat = id == "rat"
	position.y = -height * 0.5
	model = Assets.character(id, self)
	model.scale = Vector3.ONE * height / (0.58 if is_rat else (1.23 if id in ["crypt_warden", "jewel_sentinel"] else 1.08))
	body = model.find_child("Body", true, false) as Node3D
	if body:
		body_rest = body.position
	arm_r = model.find_child("ArmL", true, false) as Node3D
	arm_l = model.find_child("ArmR", true, false) as Node3D
	leg_r = model.find_child("LegL", true, false) as Node3D
	leg_l = model.find_child("LegR", true, false) as Node3D
	tail = model.find_child("Tail", true, false) as Node3D
	head = model.find_child("Head", true, false) as Node3D
	grip_r = model.find_child("GripL", true, false) as Node3D
	grip_l = model.find_child("GripR", true, false) as Node3D
	if body and arm_r and arm_l and leg_r and leg_l:
		skeleton = ArticulatedSkeleton.new()
		skeleton.name = "CharacterSkeleton"
		model.add_child(skeleton)
		skeleton.build(body, head, [arm_r, arm_l], [leg_r, leg_l], tail, is_rat)
		elbow_r = skeleton.drivers.get("ElbowR")
		elbow_l = skeleton.drivers.get("ElbowL")
		knee_r = skeleton.drivers.get("KneeR")
		knee_l = skeleton.drivers.get("KneeL")
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
	for pair in [[elbow_r if elbow_r else arm_r, 4, -0.17 if elbow_r else -0.33], [elbow_l if elbow_l else arm_l, 4, -0.17 if elbow_l else -0.33], [knee_r if knee_r else leg_r, 5, -0.14 if knee_r else -0.40], [knee_l if knee_l else leg_l, 5, -0.14 if knee_l else -0.40]]:
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

func animate(delta: float, alive: bool, phase: int, asleep: bool, hurt: bool, blocking: bool = false, casting: bool = false, hit_direction: float = 0.0, progress: float = -1.0) -> void:
	var parent := get_parent_node_3d()
	var at := parent.global_position
	var heading := parent.rotation.y
	var turn := wrapf(heading - previous_yaw, -PI, PI) if sampled else 0.0
	previous_yaw = heading
	turn_lean = lerpf(turn_lean, clampf(turn / maxf(delta, 0.001) * -0.025, -0.14, 0.14), Motion.blend(delta, 9.0))
	if phase != last_phase:
		phase_age = 0.0
		last_phase = phase
	phase_age += delta
	if hurt and not was_hurt:
		flinch = 1.0
	was_hurt = hurt
	flinch = move_toward(flinch, 0.0, delta * 4.0)
	var displacement := at - previous if sampled and absf(at.y - previous.y) < 5.0 else Vector3.ZERO
	var distance := Vector2(displacement.x, displacement.z).length()
	if distance > 0.001 and distance < 3.0:
		var travel := parent.global_basis.inverse() * displacement.normalized()
		strafe = lerpf(strafe, travel.x, Motion.blend(delta, 8.0))
		stride_direction = lerpf(stride_direction, -travel.z, Motion.blend(delta, 8.0))
	previous = at
	sampled = true
	if distance > 3.0:
		distance = 0.0
	speed = lerpf(speed, minf(8.0, distance / maxf(delta, 0.001)), Motion.blend(delta, 12.0))
	ever_alive = ever_alive or alive
	var weight := Motion.blend(delta, 14.0)
	var prone := -PI * 0.5 if not alive else (-PI * 0.45 if asleep and not is_rat else 0.0)
	pose = lerpf(pose, prone, weight)
	model.rotation.x = pose
	if not alive or asleep:
		for part in [arm_r, arm_l, leg_r, leg_l, elbow_r, elbow_l, knee_r, knee_l]:
			angle(part, 0.0, weight)
		if skeleton:
			skeleton.sync_parts()
		return
	var heavy := kind in ["brute", "guardian", "crypt_warden", "jewel_sentinel"]
	clock += delta * speed * (5.5 if is_rat else (2.6 if heavy else 3.8))
	breath_clock += delta * (2.0 if heavy else 3.0)
	var gait := sin(clock) * clampf(speed / 2.3, 0.0, 1.0) * (0.52 if heavy else 0.76)
	angle(leg_r, gait * stride_direction, weight)
	angle(leg_l, -gait * stride_direction, weight)
	if leg_r and leg_l:
		leg_r.rotation.z = lerpf(leg_r.rotation.z, gait * strafe * 0.55, weight)
		leg_l.rotation.z = lerpf(leg_l.rotation.z, -gait * strafe * 0.55, weight)
	angle(knee_r, maxf(0.0, -gait) * 1.1, weight)
	angle(knee_l, maxf(0.0, gait) * 1.1, weight)
	if skeleton and not is_rat:
		skeleton.sample_gait(clock, speed, clampf(speed / 2.3, 0.0, 1.0))
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
	if is_rat:
		windup = -0.65
		release = 0.55
	if kind == "adventurer" and not gear_key.is_empty():
		var weapon_id: String = gear_key[0]
		if "bow" in weapon_id or "spear" in weapon_id:
			windup = -0.9
			release = -1.6
		elif "axe" in weapon_id:
			windup = -2.1
			release = 0.95
	var p := progress if progress >= 0.0 else clampf(phase_age / 0.45, 0.0, 1.0)
	var attack := -gait * 0.65
	var twist := 0.0
	if phase == 1:
		attack = lerpf(attack, windup, Motion.smooth(p))
		twist = -0.22 * Motion.smooth(p)
	elif phase == 2:
		attack = lerpf(lerpf(windup, release, Motion.strike(p)), attack, Motion.settle(p))
		twist = lerpf(lerpf(-0.22, 0.32, Motion.strike(p)), 0.0, Motion.settle(p))
	angle(arm_r, -1.15 if casting else attack, weight)
	var two_handed := kind == "archer" or (kind == "adventurer" and not gear_key.is_empty() and "bow" in str(gear_key[0]))
	angle(arm_l, -1.4 if blocking or casting else (lerpf(gait * 0.65, -1.4, Motion.smooth(p)) if two_handed and phase == 1 else gait * 0.65), weight)
	var elbow_bend := 0.2 + absf(gait) * 0.2
	if phase == 1:
		elbow_bend += Motion.smooth(p) * 0.65
	elif phase == 2:
		elbow_bend += (1.0 - Motion.settle(p)) * 0.2
	angle(elbow_r, -elbow_bend if not is_rat else elbow_bend, weight)
	angle(elbow_l, -0.85 if blocking or casting or (two_handed and phase == 1) else -0.2 - absf(gait) * 0.2, weight)
	if body:
		body.position.y = lerpf(body.position.y, body_rest.y + absf(gait) * 0.035 + sin(breath_clock) * 0.008, weight)
		body.rotation.z = lerpf(body.rotation.z, -hit_direction * 0.32 * flinch + gait * 0.035 + turn_lean, weight)
		body.rotation.x = lerpf(body.rotation.x, 0.20 * flinch + (0.10 if heavy else 0.16) * clampf(speed / 4.0, 0.0, 1.0) - twist * 0.5, weight)
		body.rotation.y = lerpf(body.rotation.y, twist + gait * 0.06, weight)
	if head:
		head.rotation.x = lerpf(head.rotation.x, -0.12 if phase == 1 else (0.08 if hurt else sin(breath_clock * 0.5) * 0.025), weight)
	if tail:
		tail.rotation.y = sin(clock + breath_clock * 0.35) * 0.35
	if skeleton:
		skeleton.sync_parts()
