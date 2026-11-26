extends RefCounted

const PULL := 20.0
const MELEE_THRESHOLD := 1.1
const RANGED_THRESHOLD := 1.3

static func add(mob: Dictionary, peer: int, amount: float) -> void:
	if peer <= 0 or amount <= 0:
		return
	var table: Dictionary = mob.threat
	table[peer] = float(table.get(peer, 0.0)) + amount

static func choose(mob: Dictionary, eligible: Dictionary, distances: Dictionary) -> int:
	var table: Dictionary = mob.threat
	for id in table.keys():
		if not eligible.has(id):
			table.erase(id)
	var current: int = mob.target
	if not table.has(current):
		current = 0
	var highest := current
	var score: float = table.get(current, 0.0)
	for id in table:
		var threshold := MELEE_THRESHOLD if float(distances.get(id, 100.0)) <= 3.0 else RANGED_THRESHOLD
		if current != 0 and id != current and float(table[id]) <= float(table[current]) * threshold:
			continue
		if float(table[id]) > score:
			highest = id
			score = table[id]
	return highest
