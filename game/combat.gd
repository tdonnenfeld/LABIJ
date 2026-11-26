extends RefCounted

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const ATTACK_COST := 20.0
const WINDUP := 0.35
const RECOVERY := 0.65
const REACH := 2.4
const DAMAGE := 25.0
const BLOCK_COST := 15.0
const MONSTER_WINDUP := 0.7
const MONSTER_RECOVERY := 1.0
const MONSTER_REACH := 1.65
const MONSTER_DAMAGE := 14.0

static func facing(heading: float, offset: Vector3) -> bool:
	var flat := Vector3(offset.x, 0, offset.z)
	return flat.length_squared() < 0.001 or Vector3(-sin(heading), 0, -cos(heading)).dot(flat.normalized()) >= 0.5

static func can_hit(origin: Vector3, target: Vector3, heading: float, reach: float) -> bool:
	var offset := target - origin
	return Vector2(offset.x, offset.z).length() <= reach and facing(heading, offset)

static func clear_path(body: Node3D, target: Vector3) -> bool:
	var from := body.global_position
	var to := Vector3(target.x, from.y, target.z)
	if from.distance_squared_to(to) < 0.001:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	if body is CollisionObject3D:
		query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
