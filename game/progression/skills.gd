extends RefCounted

const IDS := ["fighting", "long_blades", "axes", "polearms", "shields", "dodging"]
const TITLES := ["Fighting", "Long Blades", "Axes", "Polearms", "Shields", "Dodging"]
const MAX_LEVEL := 27
var total_xp := 0
var xp: Array[float] = [0, 0, 0, 0, 0, 0]
var priorities: Array[int] = [1, 2, 0, 0, 1, 0]

static func threshold(level: int) -> float:
	return 25.0 * level * (level + 1)

func skill_level(index: int) -> int:
	var result := 0
	while result < MAX_LEVEL and xp[index] >= threshold(result + 1):
		result += 1
	return result

func character_level() -> int:
	return mini(MAX_LEVEL, 1 + int(sqrt(float(total_xp) / 100.0)))

func set_priority(index: int, priority: int) -> bool:
	if index < 0 or index >= IDS.size() or priority < 0 or priority > 2:
		return false
	priorities[index] = priority
	return true

func gain(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	var weights := 0
	for i in range(IDS.size()):
		if skill_level(i) < MAX_LEVEL:
			weights += priorities[i]
	if weights == 0:
		return
	for i in range(IDS.size()):
		if skill_level(i) < MAX_LEVEL:
			xp[i] = minf(threshold(MAX_LEVEL), xp[i] + float(amount) * priorities[i] / weights)

func weapon_level(id: String) -> int:
	match id:
		"axe":
			return skill_level(2)
		"spear":
			return skill_level(3)
		_:
			return skill_level(1)

func state() -> Array:
	return [total_xp, xp.duplicate(), priorities.duplicate()]

func apply(data: Array) -> void:
	total_xp = data[0]
	xp.assign(data[1])
	priorities.assign(data[2])
