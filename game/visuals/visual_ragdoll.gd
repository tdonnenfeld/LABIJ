extends Node3D

var skeleton: Skeleton3D
var bodies: Array[RigidBody3D] = []
var age := 0.0

func start(rig: Skeleton3D, impulse: Vector3) -> void:
	skeleton = rig
	top_level = true
	global_transform = Transform3D.IDENTITY
	for i in range(rig.get_bone_count()):
		var body := RigidBody3D.new()
		body.name = "Bone%d" % i
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 2.0 if i == 0 else 0.3
		body.linear_damp = 1.0
		body.angular_damp = 3.0
		var shape := SphereShape3D.new()
		shape.radius = 0.16 if i == 0 else 0.09
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		var at := rig.global_transform * rig.get_bone_global_pose(i)
		body.global_transform = at.orthonormalized()
		body.linear_velocity = impulse
		bodies.append(body)
	for i in range(bodies.size()):
		var parent_index := rig.get_bone_parent(i)
		if parent_index < 0:
			continue
		var joint := PinJoint3D.new()
		add_child(joint)
		joint.global_position = bodies[i].global_position
		joint.node_a = joint.get_path_to(bodies[parent_index])
		joint.node_b = joint.get_path_to(bodies[i])

func _physics_process(delta: float) -> void:
	if not is_instance_valid(skeleton):
		queue_free()
		return
	age += delta
	for i in range(bodies.size()):
		var at := skeleton.global_transform.affine_inverse() * bodies[i].global_transform
		skeleton.set_bone_global_pose(i, at.orthonormalized())
		if age >= 2.5:
			bodies[i].freeze = true
	if age >= 2.5:
		set_physics_process(false)
