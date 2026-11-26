extends Skeleton3D

const JointSkin = preload("res://game/visuals/joint_skin.gd")
const Loot = preload("res://game/items/loot_models.gd")
var weighted_joints: Array[MeshInstance3D] = []

var joints: Dictionary = {}
var attachments: Dictionary = {}
var rests: Dictionary = {}
var clip_player: AnimationPlayer
var animation_tree: AnimationTree
var last_clock := 0.0
var gait_started := false
var drivers: Dictionary = {}

func add_joint(id: String, parent_id: String, at: Transform3D) -> int:
	var index := get_bone_count()
	add_bone(id)
	if joints.has(parent_id):
		set_bone_parent(index, joints[parent_id])
	set_bone_rest(index, at)
	set_bone_pose_position(index, at.origin)
	set_bone_pose_rotation(index, at.basis.get_rotation_quaternion())
	joints[id] = index
	rests[id] = at
	return index

func attach_part(id: String, part: Node3D) -> void:
	var socket := BoneAttachment3D.new()
	socket.name = id + "Socket"
	add_child(socket)
	socket.bone_name = id
	drivers[id] = part
	attachments[id] = socket
	for child in part.get_children():
		if child in drivers.values() or child is BoneAttachment3D:
			continue
		if child is Node3D and not child.has_meta("bone_driver"):
			child.reparent(socket, false)

func split_limb(part: Node3D, id: String, length: float) -> Node3D:
	if not is_instance_valid(part):
		return null
	var joint := Node3D.new()
	joint.name = id
	part.add_child(joint)
	joint.position.y = -length
	for child in part.get_children():
		if child == joint or not child is Node3D:
			continue
		if child.position.y < -length:
			var local: Transform3D = child.transform
			child.reparent(joint, false)
			local.origin.y += length
			child.transform = local
	return joint

func build(body: Node3D, head: Node3D, arms: Array, legs: Array, tail: Node3D, rat: bool) -> void:
	if not body:
		return
	var body_transform := body.transform
	add_joint("Torso", "", body_transform)
	var parts := {"Torso": body}
	if head:
		add_joint("Head", "Torso", head.transform)
		parts["Head"] = head
	if tail:
		add_joint("Tail", "Torso", tail.transform)
		parts["Tail"] = tail
	for i in range(2):
		for pair in [[arms[i], "Arm", "Elbow", 0.16], [legs[i], "Leg", "Knee", 0.26]]:
			var limb: Node3D = pair[0]
			if not limb:
				continue
			var suffix := "R" if i == 0 else "L"
			var upper_id: String = pair[1] + suffix
			var lower_id: String = pair[2] + suffix
			var length: float = 0.13 if rat else pair[3]
			var lower := split_limb(limb, lower_id, length)
			add_joint(upper_id, "Torso", limb.transform)
			add_joint(lower_id, upper_id, lower.transform)
			parts[upper_id] = limb
			parts[lower_id] = lower
	for id in parts:
		parts[id].set_meta("bone_driver", true)
	for id in parts:
		attach_part(id, parts[id])
	build_clips()
	for id in ["ElbowR", "ElbowL", "KneeR", "KneeL"]:
		if not joints.has(id):
			continue
		var index: int = joints[id]
		var radius := 0.045 if rat else (0.055 if id.begins_with("Elbow") else 0.065)
		weighted_joints.append(JointSkin.sleeve(self, get_bone_parent(index), index, radius, Loot.material(Loot.LEATHER)))

func sync_parts() -> void:
	for id in attachments:
		var part: Node3D = drivers[id]
		var socket: Node3D = attachments[id]
		for child in part.get_children():
			if child is Node3D and not child.has_meta("bone_driver"):
				child.reparent(socket, false)
		set_bone_pose_position(joints[id], part.position)
		set_bone_pose_rotation(joints[id], part.quaternion)
		set_bone_pose_scale(joints[id], part.scale)

func pose_joint(id: String, angle: Vector3) -> void:
	if joints.has(id):
		set_bone_pose_rotation(joints[id], Quaternion.from_euler(angle))

func joint_position(id: String) -> Vector3:
	return get_bone_global_pose(joints[id]).origin if joints.has(id) else Vector3.ZERO

func build_clips() -> void:
	clip_player = AnimationPlayer.new()
	clip_player.name = "LocomotionClips"
	add_child(clip_player)
	var library := AnimationLibrary.new()
	for clip_id in ["idle", "walk", "run"]:
		var clip := Animation.new()
		clip.length = 1.0
		clip.loop_mode = Animation.LOOP_LINEAR
		for id in ["KneeR", "KneeL"]:
			if not drivers.has(id):
				continue
			var track := clip.add_track(Animation.TYPE_VALUE)
			var driver: Node3D = drivers[id]
			clip.track_set_path(track, NodePath(str(get_path_to(driver)) + ":rotation:x"))
			var amplitude := 0.0 if clip_id == "idle" else (0.65 if clip_id == "walk" else 1.05)
			for i in range(9):
				var fraction := float(i) / 8.0
				var bend := maxf(0.0, sin(fraction * TAU + (PI if id == "KneeR" else 0.0))) * amplitude
				clip.track_insert_key(track, fraction * clip.length, bend)
		library.add_animation(clip_id, clip)
	clip_player.add_animation_library("", library)
	clip_player.root_node = NodePath("..")
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 4.5
	space.sync = true
	for pair in [["idle", 0.0], ["walk", 2.2], ["run", 4.5]]:
		var node := AnimationNodeAnimation.new()
		node.animation = pair[0]
		space.add_blend_point(node, pair[1])
	animation_tree = AnimationTree.new()
	animation_tree.name = "LocomotionBlend"
	add_child(animation_tree)
	animation_tree.root_node = NodePath("..")
	animation_tree.anim_player = animation_tree.get_path_to(clip_player)
	animation_tree.tree_root = space
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true

func sample_gait(clock: float, speed: float, weight: float) -> void:
	if not animation_tree:
		return
	var elapsed := maxf(0.0, clock - last_clock) / TAU if gait_started else 0.0
	last_clock = clock
	gait_started = true
	animation_tree.set("parameters/blend_position", clampf(speed, 0.0, 4.5))
	animation_tree.advance(elapsed)
	for id in ["KneeR", "KneeL"]:
		if drivers.has(id):
			drivers[id].rotation.x *= weight
