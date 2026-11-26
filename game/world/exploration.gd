extends RefCounted

const Acoustics = preload("res://game/world/noise.gd")
var explored: Dictionary = {}

static func visible(tiles: Dictionary, origin: Vector2i, goal: Vector2i) -> bool:
	if not tiles.has(origin) or not tiles.has(goal):
		return false
	var steps := maxi(1, ceili(Vector2(origin).distance_to(Vector2(goal)) * 4.0))
	var previous := origin
	for i in range(1, steps + 1):
		var point := Vector2(origin).lerp(Vector2(goal), float(i) / steps)
		var cell := Vector2i(roundi(point.x), roundi(point.y))
		if not tiles.has(cell):
			return false
		if cell.x != previous.x and cell.y != previous.y:
			if not tiles.has(Vector2i(cell.x, previous.y)) or not tiles.has(Vector2i(previous.x, cell.y)):
				return false
		previous = cell
	return true

func reveal(floor_id: int, tiles: Dictionary, at: Vector3) -> void:
	var origin := Acoustics.cell(at)
	if not explored.has(floor_id):
		explored[floor_id] = {}
	var cells: Dictionary = explored[floor_id]
	for x in range(-4, 5):
		for y in range(-4, 5):
			var cell := origin + Vector2i(x, y)
			if Vector2(x, y).length() <= 4.0 and visible(tiles, origin, cell):
				cells[cell] = true
