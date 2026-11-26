extends RefCounted

const CLOSE := 1.25

static func arc(kind: String) -> float:
	match kind:
		"rat", "crypt_warden", "ember_oracle", "jewel_sentinel": return 180.0
		"archer", "mage": return 150.0
		_: return 120.0

static func alignment(heading: float, offset: Vector3) -> float:
	var flat := Vector2(offset.x, offset.z)
	if flat.length_squared() < 0.001:
		return 1.0
	return Vector2(-sin(heading), -cos(heading)).dot(flat.normalized())

static func detects(heading: float, offset: Vector3, distance_limit: float, sleeping: bool, field: float) -> bool:
	var distance := Vector2(offset.x, offset.z).length()
	if sleeping:
		return distance <= minf(1.8, distance_limit)
	if distance > distance_limit:
		return false
	return distance <= CLOSE or alignment(heading, offset) >= cos(deg_to_rad(field * 0.5))

static func rear(heading: float, offset: Vector3) -> bool:
	return alignment(heading, offset) <= -0.70710678
