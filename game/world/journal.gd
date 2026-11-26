extends RefCounted

const LIMIT := 200
var history: Array = []
var pending: Array = []
var sequence := 0

func add(category: String, message: String, floor_id: int = -1, at: Vector3 = Vector3.ZERO, floating: String = "", style: String = "", target: int = 0) -> void:
	sequence += 1
	var entry := {"id": sequence, "category": category, "message": message, "floor": floor_id, "position": at, "floating": floating, "style": style, "target": target}
	history.append(entry)
	pending.append(entry)
	if history.size() > LIMIT:
		history.pop_front()

func drain() -> Array:
	var events := pending
	pending = []
	return events
