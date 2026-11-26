extends RefCounted

# name, HP, damage, reach, speed, windup, recovery, armor, XP, color, radius, height
const TYPES := {
	"rat": ["Cave Rat", 22.0, 7.0, 1.1, 4.0, 0.35, 0.65, 0.0, 55, Color("#a99170"), 0.25, 0.55],
	"goblin": ["Goblin", 50.0, 14.0, 1.65, 2.8, 0.7, 1.0, 0.0, 100, Color("#83955c"), 0.35, 1.4],
	"brute": ["Ogre", 100.0, 24.0, 2.1, 1.8, 1.2, 1.5, 0.0, 175, Color("#a16b4c"), 0.55, 2.3],
	"archer": ["Skeleton Archer", 38.0, 10.0, 9.0, 2.4, 1.0, 1.4, 0.0, 120, Color("#d2cbb0"), 0.30, 1.65],
	"guardian": ["Iron Guardian", 85.0, 18.0, 1.8, 1.6, 0.9, 1.2, 0.35, 165, Color("#778997"), 0.45, 1.9]
	,"mage": ["Hex Mage", 45.0, 16.0, 8.0, 2.0, 1.1, 1.7, 0.0, 145, Color("#a776bb"), 0.32, 1.6],
	"crypt_warden": ["Crypt Warden", 230.0, 32.0, 3.2, 2.0, 1.5, 1.5, 0.25, 350, Color("#8096a3"), 0.65, 2.5],
	"ember_oracle": ["Ember Oracle", 180.0, 23.0, 10.0, 2.1, 1.25, 1.7, 0.0, 350, Color("#d66e47"), 0.45, 2.1],
	"jewel_sentinel": ["Jewel Sentinel", 280.0, 36.0, 3.6, 2.3, 1.6, 1.4, 0.2, 500, Color("#c3a55e"), 0.70, 2.6],
	"jewel_hunter": ["Jewel Hunter", 45.0, 12.0, 1.65, 3.5, 0.6, 0.9, 0.0, 0, Color("#b365a4"), 0.35, 1.5]
}
const ENCOUNTERS := [
	["rat", "rat", "goblin"],
	["rat", "goblin", "archer", "goblin"],
	["goblin", "brute", "archer", "guardian"],
	["guardian", "brute", "mage", "goblin", "rat"],
	["guardian", "brute", "archer"],
	["mage", "mage", "brute", "goblin"],
	["guardian", "mage", "brute"]
]

static func stats(id: String) -> Array:
	return TYPES[id]

static func resistance(kind: String, domain: int) -> float:
	if kind in ["guardian", "ember_oracle"] and domain == 6:
		return 0.35
	if kind == "mage" and domain >= 6 and domain <= 9:
		return 0.2
	return 0.0
