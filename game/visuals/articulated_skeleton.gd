extends Skeleton3D

var joints: Dictionary = {}
var attachments: Dictionary = {}
var rests: Dictionary = {}

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
	part.reparent(socket, false)
	part.transform = Transform3D.IDENTITY
	attachments[id] = part

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
		attach_part(id, parts[id])

func sync_parts() -> void:
	for id in attachments:
		var part: Node3D = attachments[id]
		var rest: Transform3D = rests[id]
		set_bone_pose_position(joints[id], rest.origin + part.position)
		set_bone_pose_rotation(joints[id], rest.basis.get_rotation_quaternion() * part.quaternion)
		part.transform = Transform3D.IDENTITY

func pose_joint(id: String, angle: Vector3) -> void:
	if joints.has(id):
		set_bone_pose_rotation(joints[id], Quaternion.from_euler(angle))

func joint_position(id: String) -> Vector3:
	return get_bone_global_pose(joints[id]).origin if joints.has(id) else Vector3.ZERO
