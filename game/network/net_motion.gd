extends RefCounted

const INTERVAL := 0.065
const SNAP_DISTANCE := 3.0

static func receive(node: Node3D, target: Vector3, angle: float, snap: bool = false, rotate: bool = true) -> void:
	if snap or not node.has_meta("net_motion") or node.position.distance_to(target) > SNAP_DISTANCE:
		node.position = target
		if rotate:
			node.rotation.y = angle
	node.set_meta("net_motion", {
		"from": node.position, "to": target, "from_yaw": node.rotation.y,
		"to_yaw": angle, "elapsed": 0.0, "rotate": rotate
	})

static func advance(node: Node3D, delta: float) -> void:
	if not node.has_meta("net_motion"):
		return
	var motion: Dictionary = node.get_meta("net_motion")
	if motion.elapsed >= INTERVAL:
		return
	motion.elapsed = minf(INTERVAL, motion.elapsed + delta)
	var weight: float = motion.elapsed / INTERVAL
	# Ease rotation separately; keep translation linear to avoid stop-start gait.
	var turn_weight := weight * (2.0 - weight)
	var start: Vector3 = motion.from
	var target: Vector3 = motion.to
	node.position = start.lerp(target, weight)
	if motion.rotate:
		node.rotation.y = lerp_angle(motion.from_yaw, motion.to_yaw, turn_weight)

static func reset(node: Node3D) -> void:
	if node.has_meta("net_motion"):
		node.remove_meta("net_motion")
