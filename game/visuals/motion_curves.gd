extends RefCounted

static func blend(delta: float, rate: float) -> float:
	return 1.0 - exp(-maxf(delta, 0.0) * rate)

static func progress(remaining: float, duration: float) -> float:
	return clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)

static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func strike(t: float) -> float:
	return smooth(t / 0.22)

static func settle(t: float) -> float:
	return smooth((t - 0.22) / 0.78)

static func swing(id: String) -> Array:
	if "axe" in id:
		return [Vector3(0.20, 0.25, 0.12), Vector3(1.5, -0.38, -0.36), Vector3(-0.22, -0.13, -0.24), Vector3(-1.35, 0.55, 0.72)]
	if "spear" in id or "dagger" in id:
		return [Vector3(0.04, 0.04, 0.22), Vector3(0.22, -0.12, -0.12), Vector3(-0.06, 0.08, -0.33), Vector3(-0.15, 0.02, 0.08)]
	if "bow" in id:
		return [Vector3(-0.11, 0.14, 0.05), Vector3(-0.12, -0.25, -0.08), Vector3(-0.10, 0.13, -0.10), Vector3(-0.16, -0.18, 0.02)]
	if "staff" in id:
		return [Vector3(0.12, 0.18, 0.08), Vector3(0.8, -0.4, -0.5), Vector3(-0.20, 0.04, -0.24), Vector3(-0.65, 0.6, 0.65)]
	return [Vector3(0.16, 0.15, 0.08), Vector3(0.85, -0.65, -0.52), Vector3(-0.29, 0.08, -0.22), Vector3(-0.82, 0.75, 0.85)]
