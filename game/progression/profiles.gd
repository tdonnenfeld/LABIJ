extends RefCounted

# name, description, HP modifier, movement, mana regeneration, noise multiplier, aptitudes
const SPECIES := [
	["Human", "Balanced, with no modifiers.", 0.0, 1.0, 1.0, 1.0, {}],
	["Dwarf", "+15 HP, -8% speed; +20% Shields and Earth XP.", 15.0, 0.92, 1.0, 1.0, {4: 1.2, 9: 1.2}],
	["Elf", "-10 HP, +20% mana regen; +20% Ice and Air XP.", -10.0, 1.0, 1.2, 1.0, {7: 1.2, 8: 1.2}],
	["Halfling", "-10 HP, -20% noise; +20% Archery and Stealth XP.", -10.0, 1.0, 1.0, 0.8, {10: 1.2, 11: 1.2}]
]

# name, description, starting items, priorities, starting XP domain
const BACKGROUNDS := [
	["Adventurer", "Sword, shield and potion. Balanced allocation.", ["sword", "shield", "potion"], [1, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], -1],
	["Vanguard", "Axe, iron shield and potion. 25 Shields XP.", ["axe", "iron_shield", "potion"], [1, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0], 4],
	["Scout", "Shortbow, shield, potion and Noise Stone. 25 Stealth XP.", ["bow", "shield", "potion", "noise_stone"], [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 2], 11],
	["Arcanist", "Staff, shield, potion and Fire Bolt scroll. 25 Fire XP.", ["staff", "shield", "potion", "scroll_firebolt"], [1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0], 6]
]

static func valid(species: int, background: int) -> bool:
	return species >= 0 and species < SPECIES.size() and background >= 0 and background < BACKGROUNDS.size()

static func clean_name(value: String) -> String:
	var result := ""
	for i in range(mini(value.length(), 64)):
		var character := value.unicode_at(i)
		if character >= 32 and character != 127 and not (character >= 128 and character <= 159) and not (character >= 8232 and character <= 8238):
			result += value[i]
		if result.length() >= 24:
			break
	return result.strip_edges()
