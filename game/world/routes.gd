extends RefCounted

const MAIN_COUNT := 4
const COUNT := 7
const SANCTUARY := 6
const NAMES := ["Dungeon 1", "Dungeon 2", "Dungeon 3", "Dungeon 4", "Iron Crypt", "Ember Vault", "Jewel Sanctuary"]
const PARENTS := {4: 1, 5: 2, 6: 3}
const BOSSES := {4: "crypt_warden", 5: "ember_oracle", 6: "jewel_sentinel"}
const REWARDS := {"crypt_warden": "warden_shield", "ember_oracle": "oracle_staff", "jewel_sentinel": "potion"}

static func depth(floor_id: int) -> int:
	return floor_id if floor_id < MAIN_COUNT else int(PARENTS[floor_id]) + 1
