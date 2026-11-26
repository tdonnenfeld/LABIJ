extends RefCounted

static func elbow_position(start: Vector3, target: Vector3, pole: Vector3, a: float, b: float) -> Vector3:
	var offset := target - start
	var distance := clampf(offset.length(), absf(a - b) + 0.0001, a + b - 0.0001)
	var axis := offset.normalized() if offset.length_squared() > 0.000001 else Vector3.DOWN
	var bend := pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.000001:
		bend = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD)
	bend = bend.normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	return start + axis * along + bend * sqrt(maxf(0.0, a * a - along * along))

static func align(part: Node3D, direction: Vector3, weight: float, axis: Vector3 = Vector3.DOWN) -> void:
	if direction.length_squared() < 0.000001:
		return
	var parent := part.get_parent_node_3d()
	var local := parent.global_basis.inverse() * direction
	var current := part.quaternion
	var from := current * axis.normalized()
	var rotation := Quaternion(from.normalized(), local.normalized()) * current
	part.quaternion = current.slerp(rotation.normalized(), clampf(weight, 0.0, 1.0))

static func solve(upper: Node3D, lower: Node3D, endpoint: Vector3, target: Vector3, pole: Vector3, weight: float) -> void:
	if not upper or not lower:
		return
	var start := upper.global_position
	var a := start.distance_to(lower.global_position)
	var b := lower.global_position.distance_to(lower.to_global(endpoint))
	if minf(a, b) < 0.001:
		return
	var offset := target - start
	if offset.length_squared() < 0.000001:
		return
	var reachable := start + offset.normalized() * clampf(offset.length(), absf(a - b) + 0.0001, a + b - 0.0001)
	var joint := elbow_position(start, reachable, pole, a, b)
	align(upper, joint - start, weight, lower.position)
	align(lower, reachable - lower.global_position, weight, endpoint)
