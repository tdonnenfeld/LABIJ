extends RefCounted

# domain, mana, damage, speed, range, cooldown, color, effect
const SPELLS := {
	"firebolt": [6, 15.0, 22.0, 12.0, 15.0, 4.0, Color("#e9823c"), "burn"],
	"fireball": [6, 25.0, 30.0, 9.0, 15.0, 8.0, Color("#f5b245"), "blast"],
	"frostbolt": [7, 15.0, 15.0, 12.0, 15.0, 4.0, Color("#83d9f1"), "slow"],
	"freeze": [7, 25.0, 18.0, 10.0, 14.0, 9.0, Color("#c3ebff"), "freeze"],
	"spark": [8, 15.0, 23.0, 42.0, 15.0, 4.0, Color("#e7e18a"), "shock"],
	"thunder": [8, 25.0, 32.0, 65.0, 15.0, 9.0, Color("#f5f2bd"), "chain"],
	"stonebolt": [9, 15.0, 30.0, 8.0, 14.0, 5.0, Color("#b39a75"), "stone"],
	"boulder": [9, 25.0, 44.0, 7.0, 14.0, 9.0, Color("#96846d"), "stone"]
}

static func get_spell(id: String) -> Array:
	return SPELLS.get(id, [])
