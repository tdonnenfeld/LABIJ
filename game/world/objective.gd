extends RefCounted

const REQUIRED := ["iron", "ember"]
const RUNES := {"crypt_warden": "iron", "ember_oracle": "ember"}
var runes: Array[String] = []
var guardian_defeated := false
var carrier := 0
var jewel_floor := 6
var jewel_position := Vector3.ZERO
var started := false
var elapsed := 0.0
var result := ""
var winner := 0

func gate_open() -> bool:
	for rune in REQUIRED:
		if not runes.has(rune):
			return false
	return true

func boss_defeated(kind: String) -> void:
	if RUNES.has(kind) and not runes.has(RUNES[kind]):
		runes.append(RUNES[kind])
	if kind == "jewel_sentinel":
		guardian_defeated = true

func claim(peer: int) -> bool:
	if peer <= 0 or not gate_open() or not guardian_defeated or carrier != 0 or result != "":
		return false
	carrier = peer
	started = true
	return true

func drop(peer: int, floor_id: int, at: Vector3) -> bool:
	if peer != carrier or carrier == 0 or result != "":
		return false
	carrier = 0
	jewel_floor = floor_id
	jewel_position = at
	return true

func escape(peer: int) -> bool:
	if not started or peer != carrier or carrier == 0 or result != "":
		return false
	winner = peer
	result = "victory"
	return true

func pressure() -> int:
	return mini(3, 1 + floori(elapsed / 45.0)) if started else 0

func state() -> Dictionary:
	return {"runes": runes.duplicate(), "guardian": guardian_defeated, "carrier": carrier, "floor": jewel_floor, "position": jewel_position, "started": started, "elapsed": elapsed, "result": result, "winner": winner}

func apply(data: Dictionary) -> void:
	if result != "":
		return
	runes.assign(data["runes"])
	guardian_defeated = data["guardian"]
	carrier = data["carrier"]
	jewel_floor = data["floor"]
	jewel_position = data["position"]
	started = data["started"]
	elapsed = data["elapsed"]
	result = data["result"]
	winner = data["winner"]
