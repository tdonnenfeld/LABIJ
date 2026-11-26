extends RefCounted

const MAIN_COUNT := 4
const COUNT := 6
const NAMES := ["Dungeon 1", "Dungeon 2", "Dungeon 3", "Dungeon 4", "Iron Crypt", "Ember Vault"]
const PARENTS := {4: 1, 5: 2}
const BOSSES := {4: "crypt_warden", 5: "ember_oracle"}
const REWARDS := {"crypt_warden": "warden_shield", "ember_oracle": "oracle_staff"}

static func depth(floor_id: int) -> int:
	return floor_id if floor_id < MAIN_COUNT else int(PARENTS[floor_id]) + 1
