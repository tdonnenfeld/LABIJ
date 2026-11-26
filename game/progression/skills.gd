extends RefCounted

const Talents = preload("res://game/progression/talents.gd")
const TITLES := ["Fighting", "Long Blades", "Axes", "Polearms", "Shields", "Dodging", "Fire Magic", "Ice Magic", "Air Magic", "Earth Magic", "Archery"]
const SLOT_COUNT := 3
const Spells = preload("res://game/combat/spells.gd")
const SCROLL_REQUIREMENTS := {"firebolt": 1, "frostbolt": 1, "spark": 1, "stonebolt": 1, "fireball": 2, "freeze": 2, "thunder": 2, "boulder": 2}
var total_xp := 0
var xp: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var wallet: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var priorities: Array[int] = [1, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0]
var learned: Array[String] = []
var discovered: Array[String] = []
var slots: Array[String] = ["", "", ""]
var cooldowns: Dictionary = {}

func character_level() -> int:
	return 1 + int(sqrt(float(total_xp) / 100.0))

func set_priority(index: int, priority: int) -> bool:
	if index < 0 or index >= TITLES.size() or priority < 0 or priority > 2:
		return false
	priorities[index] = priority
	return true

func credit(domain: int, amount: float) -> void:
	if domain >= 0 and domain < TITLES.size() and amount > 0:
		xp[domain] += amount
		wallet[domain] += amount

func gain(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	var weights := 0
	for weight in priorities:
		weights += weight
	if weights > 0:
		for i in range(TITLES.size()):
			credit(i, float(amount) * priorities[i] / weights)

func weapon_domain(id: String) -> int:
	match id:
		"axe": return 2
		"spear": return 3
		"bow", "longbow": return 10
		_: return 1

func visible(node: Array) -> bool:
	return not node[8] or discovered.has(node[0])

func can_buy(id: String) -> bool:
	var node := Talents.find(id)
	return not node.is_empty() and not SCROLL_REQUIREMENTS.has(id) and visible(node) and not learned.has(id) and wallet[node[1]] >= node[3] and (node[4] == "" or learned.has(node[4]))

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var node := Talents.find(id)
	wallet[node[1]] -= node[3]
	learned.append(id)
	return true

func assign_slot(index: int, id: String) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	if id != "":
		var node := Talents.find(id)
		if node.is_empty() or not learned.has(id) or node[5] != "active":
			return false
		for i in range(SLOT_COUNT):
			if slots[i] == id:
				slots[i] = ""
	slots[index] = id
	return true

func bonus(effect: String, domain: int = -1) -> float:
	var result := 0.0
	for id in learned:
		var node := Talents.find(id)
		if node[5] == effect and (domain == -1 or node[1] == domain):
			result += float(node[6])
	return result

func state() -> Array:
	return [total_xp, xp.duplicate(), priorities.duplicate(), wallet.duplicate(), learned.duplicate(), discovered.duplicate(), slots.duplicate(), cooldowns.duplicate()]

func apply(data: Array) -> void:
	total_xp = data[0]
	xp.assign(data[1])
	priorities.assign(data[2])
	wallet.assign(data[3])
	learned.assign(data[4])
	discovered.assign(data[5])
	slots.assign(data[6])
	cooldowns = data[7].duplicate()

func mastery(domain: int) -> int:
	if domain < 0 or domain >= TITLES.size():
		return 0
	return int(sqrt(xp[domain] / 25.0))

func read_scroll(id: String) -> bool:
	if not SCROLL_REQUIREMENTS.has(id) or learned.has(id):
		return false
	var node := Talents.find(id)
	if node.is_empty() or mastery(node[1]) < SCROLL_REQUIREMENTS[id]:
		return false
	learned.append(id)
	return true
