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
	var forced: int = mob.get("forced_target", 0)
	if mob.get("force_timer", 0.0) > 0 and eligible.has(forced):
		return forced
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

static func taunt(mob: Dictionary, peer: int) -> void:
	var highest := PULL
	for value in mob.threat.values():
		highest = maxf(highest, value)
	mob.threat[peer] = highest
	mob.target = peer
	mob.forced_target = peer
	mob.force_timer = 3.0

static func reduce(mob: Dictionary, peer: int) -> bool:
	if not mob.threat.has(peer):
		return false
	mob.threat[peer] *= 0.5
	if mob.target == peer:
		mob.target = 0
	if mob.get("forced_target", 0) == peer:
		mob.force_timer = 0.0
	return true
