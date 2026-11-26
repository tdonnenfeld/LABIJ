extends RefCounted

# name, HP, damage, reach, speed, windup, recovery, armor, XP, color, radius, height
const TYPES := {
	"rat": ["Cave Rat", 22.0, 7.0, 1.1, 4.0, 0.35, 0.65, 0.0, 55, Color("#a99170"), 0.25, 0.55],
	"goblin": ["Goblin", 50.0, 14.0, 1.65, 2.8, 0.7, 1.0, 0.0, 100, Color("#83955c"), 0.35, 1.4],
	"brute": ["Ogre", 100.0, 24.0, 2.1, 1.8, 1.2, 1.5, 0.0, 175, Color("#a16b4c"), 0.55, 2.3],
	"archer": ["Skeleton Archer", 38.0, 10.0, 9.0, 2.4, 1.0, 1.4, 0.0, 120, Color("#d2cbb0"), 0.30, 1.65],
	"guardian": ["Iron Guardian", 85.0, 18.0, 1.8, 1.6, 0.9, 1.2, 0.35, 165, Color("#778997"), 0.45, 1.9]
}
const ENCOUNTERS := [
	["rat", "rat", "goblin"],
	["rat", "goblin", "archer", "goblin"],
	["goblin", "brute", "archer", "guardian"],
	["guardian", "brute", "archer", "goblin", "rat"]
]

static func stats(id: String) -> Array:
	return TYPES[id]
