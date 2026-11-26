extends RefCounted

const CELL := 3.0
const QUIET := 2.5
const WALK := 6.0
const SPRINT := 12.0
const MELEE := 9.0
const BOW := 5.0
const MAGIC := 13.0
const EXPLOSION := 18.0

static func cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))

static func reach(tiles: Dictionary, origin: Vector3, radius: float) -> Dictionary:
	var start := cell(origin)
	var distances := {}
	if not tiles.has(start):
		return distances
	distances[start] = 0
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	var limit := ceili(radius / CELL) + 1
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if distances[current] >= limit:
			continue
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if tiles.has(next) and not distances.has(next):
				distances[next] = distances[current] + 1
				queue.append(next)
	return distances

static func audible(distances: Dictionary, origin: Vector3, listener: Vector3, radius: float) -> bool:
	var destination := cell(listener)
	if not distances.has(destination):
		return false
	var direct := Vector2(origin.x - listener.x, origin.z - listener.z).length()
	var steps: int = distances[destination]
	return direct <= radius and (steps <= 1 or steps * CELL - CELL <= radius)
